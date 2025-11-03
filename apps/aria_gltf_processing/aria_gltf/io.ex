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
    alias AriaGltf.Import.BinaryLoader
    BinaryLoader.load_glb(file_path)
  end

  @doc """
  Saves a glTF document as binary glTF (GLB) file.
  """
  @spec save_binary(Document.t(), String.t()) :: :ok | {:error, term()}
  def save_binary(%Document{} = document, file_path) when is_binary(file_path) do
    with :ok <- validate_document(document),
         :ok <- ensure_directory_exists(file_path),
         {:ok, glb_data} <- create_glb_binary(document),
         :ok <- write_file(file_path, glb_data) do
      :ok
    end
  end

  def save_binary(_, _), do: {:error, :invalid_arguments}

  # GLB format constants
  @glb_magic 0x46546C67  # "glTF" in little endian
  @glb_version 2
  @json_chunk_type 0x4E4F534A  # "JSON" in little endian
  @bin_chunk_type 0x004E4942  # "BIN\0" in little endian

  # Creates GLB binary format from document
  defp create_glb_binary(document) do
    with {:ok, json_bytes} <- serialize_document_to_bytes(document),
         {:ok, bin_data} <- extract_first_buffer_data(document),
         {:ok, glb_bytes} <- build_glb_binary(json_bytes, bin_data) do
      {:ok, glb_bytes}
    end
  end

  # Serialize document to JSON bytes
  defp serialize_document_to_bytes(document) do
    json_map = Document.to_json(document)
    case Jason.encode!(json_map) do
      json_string when is_binary(json_string) ->
        {:ok, json_string}
      error ->
        {:error, {:json_encode_failed, error}}
    end
  end

  # Extract binary data from first buffer (for GLB BIN chunk)
  defp extract_first_buffer_data(%Document{buffers: [%{data: data} | _]}) when is_binary(data) do
    {:ok, data}
  end

  defp extract_first_buffer_data(%Document{buffers: []}) do
    {:ok, <<>>}
  end

  defp extract_first_buffer_data(%Document{buffers: nil}) do
    {:ok, <<>>}
  end

  defp extract_first_buffer_data(_) do
    {:ok, <<>>}
  end

  # Build GLB binary format: header + JSON chunk + BIN chunk
  defp build_glb_binary(json_bytes, bin_data) do
    # Pad JSON chunk to 4-byte boundary (with spaces 0x20)
    json_padded = pad_chunk(json_bytes, @json_chunk_type)
    json_chunk_length = byte_size(json_padded)
    
    # Pad BIN chunk to 4-byte boundary (with zeros 0x00)
    bin_padded = pad_chunk(bin_data, @bin_chunk_type)
    bin_chunk_length = byte_size(bin_padded)
    
    # Calculate total length: 12 (header) + 8 + json_chunk_length + 8 + bin_chunk_length
    total_length = 12 + 8 + json_chunk_length + 8 + bin_chunk_length
    
    # Build GLB structure
    header = <<@glb_magic::little-32, @glb_version::little-32, total_length::little-32>>
    json_chunk_header = <<json_chunk_length::little-32, @json_chunk_type::little-32>>
    bin_chunk_header = <<bin_chunk_length::little-32, @bin_chunk_type::little-32>>
    
    glb_binary = header <> json_chunk_header <> json_padded <> bin_chunk_header <> bin_padded
    {:ok, glb_binary}
  end

  # Pad chunk data to 4-byte boundary
  defp pad_chunk(data, @json_chunk_type) do
    # JSON chunks padded with spaces (0x20)
    pad_json_chunk(data)
  end

  defp pad_chunk(data, @bin_chunk_type) do
    # Binary chunks padded with zeros (0x00)
    pad_bin_chunk(data)
  end

  defp pad_chunk(data, _), do: data

  defp pad_json_chunk(data) when rem(byte_size(data), 4) == 0, do: data

  defp pad_json_chunk(data) do
    padding_size = 4 - rem(byte_size(data), 4)
    padding = String.duplicate(<<0x20>>, padding_size)
    data <> padding
  end

  defp pad_bin_chunk(data) when rem(byte_size(data), 4) == 0, do: data

  defp pad_bin_chunk(data) do
    padding_size = 4 - rem(byte_size(data), 4)
    padding = :binary.copy(<<0>>, padding_size)
    data <> padding
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
