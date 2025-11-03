# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.IO do
  @moduledoc """
  Input/Output functionality for glTF files.

  This module provides functions to export glTF documents to files on disk.
  It uses the existing Document serialization capabilities to create valid
  glTF JSON files.
  """

  alias AriaGltf.Document

  @doc """
  Exports a glTF document to a file.

  Takes a Document struct and writes it as a JSON glTF file to the specified path.
  The file will be created with proper glTF 2.0 formatting.

  ## Parameters

  - `document` - A valid AriaGltf.Document struct
  - `file_path` - The path where the glTF file should be written

  ## Returns

  - `{:ok, file_path}` - On successful export
  - `{:error, reason}` - On failure

  ## Examples

      iex> document = %AriaGltf.Document{asset: %AriaGltf.Asset{version: "2.0"}}
      iex> AriaGltf.IO.export_to_file(document, "/tmp/test.gltf")
      {:ok, "/tmp/test.gltf"}

  """
  @spec export_to_file(Document.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def export_to_file(%Document{} = document, file_path) when is_binary(file_path) do
    with :ok <- validate_document(document),
         :ok <- ensure_directory_exists(file_path),
         {:ok, json_content} <- serialize_document(document),
         :ok <- write_file(file_path, json_content) do
      {:ok, file_path}
    end
  end

  def export_to_file(_, _), do: {:error, :invalid_arguments}

  @doc """
  Validates that a document is suitable for export.
  """
  @spec validate_document(Document.t()) :: :ok | {:error, term()}
  def validate_document(%Document{asset: nil}), do: {:error, :missing_asset}

  def validate_document(%Document{asset: %{version: version}}) when version != "2.0" do
    {:error, {:unsupported_version, version}}
  end

  def validate_document(%Document{}), do: :ok

  @doc """
  Ensures the target directory exists, creating it if necessary.
  """
  @spec ensure_directory_exists(String.t()) :: :ok | {:error, term()}
  def ensure_directory_exists(file_path) do
    dir_path = Path.dirname(file_path)

    case File.mkdir_p(dir_path) do
      :ok -> :ok
      {:error, reason} -> {:error, {:directory_creation_failed, reason}}
    end
  end

  @doc """
  Serializes a document to JSON format.
  """
  @spec serialize_document(Document.t()) :: {:ok, String.t()} | {:error, term()}
  def serialize_document(%Document{} = document) do
    try do
      json_data = Document.to_json(document)
      json_string = Jason.encode!(json_data, pretty: true)
      {:ok, json_string}
    rescue
      error -> {:error, {:serialization_failed, error}}
    end
  end

  @doc """
  Writes content to a file with proper error handling.
  """
  @spec write_file(String.t(), String.t()) :: :ok | {:error, term()}
  def write_file(file_path, content) do
    case File.write(file_path, content) do
      :ok -> :ok
      {:error, reason} -> {:error, {:file_write_failed, reason}}
    end
  end

  @doc """
  Imports a glTF document from a file with comprehensive validation.

  This is the main import function that provides robust JSON parsing,
  document validation, and configurable error handling.

  ## Options

  - `:validation_mode` - Validation mode `:strict` (default), `:permissive`, or `:warning_only`
  - `:check_indices` - Whether to validate index references (default: true)
  - `:check_extensions` - Whether to validate extensions (default: true)
  - `:check_schema` - Whether to validate against JSON schema (default: true)
  - `:continue_on_errors` - Whether to continue parsing on non-critical errors (default: false)

  ## Examples

      iex> AriaGltf.IO.import_from_file("model.gltf")
      {:ok, %AriaGltf.Document{...}}

      iex> AriaGltf.IO.import_from_file("model.gltf", validation_mode: :permissive)
      {:ok, %AriaGltf.Document{...}}

      iex> AriaGltf.IO.import_from_file("invalid.gltf")
      {:error, %AriaGltf.Validation.Report{errors: [...]}}
  """
  @spec import_from_file(String.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def import_from_file(file_path, opts \\ []) when is_binary(file_path) do
    continue_on_errors = Keyword.get(opts, :continue_on_errors, false)

    with {:ok, content} <- read_file_with_recovery(file_path),
         {:ok, json_data} <- parse_json_with_recovery(content, continue_on_errors),
         {:ok, document} <- parse_document_with_recovery(json_data, continue_on_errors),
         {:ok, validated_document} <- validate_imported_document(document, opts) do
      {:ok, validated_document}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads a glTF document from a file (legacy function, use import_from_file/2 instead).
  """
  @spec load_file(String.t()) :: {:ok, Document.t()} | {:error, term()}
  def load_file(file_path) when is_binary(file_path) do
    import_from_file(file_path, validation_mode: :warning_only)
  end

  @doc """
  Saves a glTF document to a file.
  """
  @spec save_file(Document.t(), String.t()) :: :ok | {:error, term()}
  def save_file(document, file_path) do
    case export_to_file(document, file_path) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads a binary glTF (GLB) file.
  """
  @spec load_binary(String.t()) :: {:ok, Document.t()} | {:error, term()}
  def load_binary(file_path) when is_binary(file_path) do
    raise "TODO: Implement #{__MODULE__}.load_binary"
  end

  @doc """
  Saves a glTF document as binary glTF (GLB) file.
  """
  @spec save_binary(Document.t(), String.t()) :: :ok | {:error, term()}
  def save_binary(_document, _file_path) do
    raise "TODO: Implement #{__MODULE__}.save_binary"
  end

  @doc """
  Creates a minimal valid glTF document for testing purposes.

  Returns a Document struct with the minimum required fields to create
  a valid glTF 2.0 file.
  """
  @spec create_minimal_document() :: Document.t()
  def create_minimal_document do
    %Document{
      asset: %AriaGltf.Asset{
        version: "2.0",
        generator: "aria_gltf"
      },
      scenes: [],
      nodes: [],
      meshes: [],
      materials: [],
      textures: [],
      images: [],
      samplers: [],
      buffers: [],
      buffer_views: [],
      accessors: [],
      animations: []
    }
  end

  # Private helper functions for import functionality

  @spec read_file_with_recovery(String.t()) :: {:ok, String.t()} | {:error, term()}
  defp read_file_with_recovery(file_path) do
    case File.read(file_path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, {:file_not_found, file_path}}
      {:error, :eacces} -> {:error, {:file_access_denied, file_path}}
      {:error, reason} -> {:error, {:file_read_failed, reason}}
    end
  end

  @spec parse_json_with_recovery(String.t(), boolean()) :: {:ok, map()} | {:error, term()}
  defp parse_json_with_recovery(content, continue_on_errors) do
    case Jason.decode(content) do
      {:ok, json_data} when is_map(json_data) ->
        {:ok, json_data}

      {:ok, _} ->
        {:error, :invalid_json_structure}

      {:error, %Jason.DecodeError{} = error} ->
        if continue_on_errors do
          # Try to recover from common JSON issues
          attempt_json_recovery(content)
        else
          {:error, {:json_parse_failed, error}}
        end
    end
  end

  @spec parse_document_with_recovery(map(), boolean()) :: {:ok, Document.t()} | {:error, term()}
  defp parse_document_with_recovery(json_data, continue_on_errors) do
    case Document.from_json(json_data) do
      {:ok, document} ->
        {:ok, document}

      {:error, reason} ->
        if continue_on_errors do
          # Try to create a partial document from available data
          attempt_partial_document_creation(json_data, reason)
        else
          {:error, {:document_parse_failed, reason}}
        end
    end
  end

  @spec validate_imported_document(Document.t(), keyword()) ::
          {:ok, Document.t()} | {:error, term()}
  defp validate_imported_document(document, opts) do
    validation_mode = Keyword.get(opts, :validation_mode, :strict)
    validation_overrides = Keyword.get(opts, :validation_overrides, [])

    validation_opts =
      opts
      |> Keyword.put(:mode, validation_mode)
      |> Keyword.put(:overrides, validation_overrides)

    case AriaGltf.Validation.validate(document, validation_opts) do
      {:ok, validated_document} -> {:ok, validated_document}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec attempt_json_recovery(String.t()) :: {:ok, map()} | {:error, term()}
  defp attempt_json_recovery(content) do
    # Try common JSON fixes
    content
    |> fix_trailing_commas()
    |> fix_single_quotes()
    |> fix_unquoted_keys()
    |> Jason.decode()
    |> case do
      {:ok, json_data} when is_map(json_data) -> {:ok, json_data}
      _ -> {:error, :json_recovery_failed}
    end
  end

  @spec attempt_partial_document_creation(map(), term()) :: {:ok, Document.t()} | {:error, term()}
  defp attempt_partial_document_creation(json_data, _original_error) do
    # Create a minimal document with whatever valid data we can extract
    case Map.get(json_data, "asset") do
      nil ->
        {:error, :missing_required_asset}

      asset_data ->
        case create_partial_document(json_data, asset_data) do
          {:ok, document} -> {:ok, document}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @spec create_partial_document(map(), map()) :: {:ok, Document.t()} | {:error, term()}
  defp create_partial_document(json_data, asset_data) do
    try do
      document = %Document{
        asset: %AriaGltf.Asset{
          version: Map.get(asset_data, "version", "2.0"),
          generator: Map.get(asset_data, "generator", "unknown"),
          copyright: Map.get(asset_data, "copyright"),
          min_version: Map.get(asset_data, "minVersion")
        },
        scenes: Map.get(json_data, "scenes", []),
        nodes: Map.get(json_data, "nodes", []),
        meshes: Map.get(json_data, "meshes", []),
        materials: Map.get(json_data, "materials", []),
        textures: Map.get(json_data, "textures", []),
        images: Map.get(json_data, "images", []),
        samplers: Map.get(json_data, "samplers", []),
        buffers: Map.get(json_data, "buffers", []),
        buffer_views: Map.get(json_data, "bufferViews", []),
        accessors: Map.get(json_data, "accessors", []),
        animations: Map.get(json_data, "animations", [])
      }

      {:ok, document}
    rescue
      _ -> {:error, :partial_document_creation_failed}
    end
  end

  # JSON recovery helper functions

  @spec fix_trailing_commas(String.t()) :: String.t()
  defp fix_trailing_commas(content) do
    content
    |> String.replace(~r/,\s*}/, "}")
    |> String.replace(~r/,\s*]/, "]")
  end

  @spec fix_single_quotes(String.t()) :: String.t()
  defp fix_single_quotes(content) do
    # Simple replacement - may need more sophisticated handling
    String.replace(content, "'", "\"")
  end

  @spec fix_unquoted_keys(String.t()) :: String.t()
  defp fix_unquoted_keys(content) do
    # Replace common unquoted keys with quoted versions
    content
    |> String.replace(~r/(\w+):/, "\"\\1\":")
  end
end
