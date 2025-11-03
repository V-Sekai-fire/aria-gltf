# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import do
  @moduledoc """
  Main import interface for loading glTF files and binary data.

  This module provides the primary API for importing glTF content from various sources
  including files, URLs, and binary data streams.
  """

  alias AriaGltf.Document
  alias AriaGltf.Import.{Parser, BinaryLoader}
  alias AriaGltf.Validation

  @type import_source :: String.t() | binary() | URI.t()
  @type import_options :: [
          validate: boolean(),
          validation_mode: Validation.validation_mode(),
          load_buffers: boolean(),
          load_images: boolean(),
          base_uri: String.t() | nil
        ]
  @type import_result :: {:ok, Document.t()} | {:error, term()}

  @doc """
  Imports a glTF document from a file path.

  ## Options

  - `:validate` - Whether to validate the document (default: true)
  - `:validation_mode` - Validation mode `:strict`, `:permissive`, or `:warning_only` (default: :strict)
  - `:load_buffers` - Whether to load buffer data (default: true)
  - `:load_images` - Whether to load image data (default: false)
  - `:base_uri` - Base URI for resolving relative references (default: file directory)

  ## Examples

      iex> AriaGltf.Import.from_file("model.gltf")
      {:ok, %AriaGltf.Document{...}}

      iex> AriaGltf.Import.from_file("model.gltf", validate: false)
      {:ok, %AriaGltf.Document{...}}

      iex> AriaGltf.Import.from_file("invalid.gltf")
      {:error, %AriaGltf.Validation.Report{...}}
  """
  @spec from_file(String.t(), import_options()) :: import_result()
  def from_file(file_path, opts \\ []) when is_binary(file_path) do
    with {:ok, content} <- File.read(file_path),
         base_uri <- opts[:base_uri] || Path.dirname(file_path) do
      opts = Keyword.put(opts, :base_uri, base_uri)

      case Path.extname(file_path) do
        ".gltf" -> from_json(content, opts)
        ".glb" -> from_binary(content, opts)
        ext -> {:error, "Unsupported file extension: #{ext}"}
      end
    else
      error -> error
    end
  end

  @doc """
  Imports a glTF document from JSON content.

  ## Examples

      iex> json = File.read!("model.gltf")
      iex> AriaGltf.Import.from_json(json)
      {:ok, %AriaGltf.Document{...}}
  """
  @spec from_json(String.t(), import_options()) :: import_result()
  def from_json(json_content, opts \\ []) when is_binary(json_content) do
    with {:ok, parsed} <- Jason.decode(json_content),
         result <- Parser.parse_and_validate(parsed) do
      case result do
        {:ok, document} ->
          if Keyword.get(opts, :validate, true) do
            validate_and_finalize(document, opts)
          else
            finalize_document(document, opts)
          end

        {:error, _} = error ->
          error
      end
    else
      error -> error
    end
  end

  @doc """
  Imports a glTF document from binary GLB content.

  ## Examples

      iex> glb_data = File.read!("model.glb")
      iex> AriaGltf.Import.from_binary(glb_data)
      {:ok, %AriaGltf.Document{...}}
  """
  @spec from_binary(binary(), import_options()) :: import_result()
  def from_binary(glb_content, opts \\ []) when is_binary(glb_content) do
    with {:ok, {json_chunk, bin_chunk}} <- BinaryLoader.parse_glb(glb_content),
         {:ok, parsed} <- Jason.decode(json_chunk),
         result <- Parser.parse_and_validate(parsed) do
      case result do
        {:ok, document} ->
          # Inject binary buffer data
          document = inject_binary_buffer(document, bin_chunk)

          if Keyword.get(opts, :validate, true) do
            validate_and_finalize(document, opts)
          else
            finalize_document(document, opts)
          end

        {:error, _} = error ->
          error
      end
    else
      error -> error
    end
  end

  @doc """
  Imports a glTF document from a URL.

  ## Examples

      iex> AriaGltf.Import.from_url("https://example.com/model.gltf")
      {:ok, %AriaGltf.Document{...}}
  """
  @spec from_url(String.t(), import_options()) :: import_result()
  def from_url(url, opts \\ []) when is_binary(url) do
    with {:ok, response} <- fetch_url(url),
         base_uri <- opts[:base_uri] || extract_base_uri(url) do
      opts = Keyword.put(opts, :base_uri, base_uri)

      case detect_content_type(response.headers, url) do
        :json -> from_json(response.body, opts)
        :binary -> from_binary(response.body, opts)
        :unknown -> {:error, "Unable to determine content type from URL: #{url}"}
      end
    else
      error -> error
    end
  end

  @doc """
  Validates an already imported document.

  ## Examples

      iex> {:ok, document} = AriaGltf.Import.from_file("model.gltf", validate: false)
      iex> AriaGltf.Import.validate(document)
      {:ok, document}
  """
  @spec validate(Document.t(), import_options()) ::
          {:ok, Document.t()} | {:error, Validation.Report.t()}
  def validate(%Document{} = document, opts \\ []) do
    validation_mode = Keyword.get(opts, :validation_mode, :strict)

    case Validation.validate(document, mode: validation_mode) do
      {:ok, validated_document} -> {:ok, validated_document}
      {:error, report} -> {:error, report}
    end
  end

  # Private functions

  defp validate_and_finalize(document, opts) do
    case validate(document, opts) do
      {:ok, validated_document} -> finalize_document(validated_document, opts)
      {:error, _} = error -> error
    end
  end

  defp finalize_document(document, opts) do
    document
    |> maybe_load_buffers(opts)
    |> maybe_load_images(opts)
    |> case do
      {:ok, final_document} -> {:ok, final_document}
      {:error, _} = error -> error
    end
  end

  defp maybe_load_buffers(document, opts) do
    if Keyword.get(opts, :load_buffers, true) do
      BinaryLoader.load_buffers(document, opts)
    else
      {:ok, document}
    end
  end

  defp maybe_load_images(document, opts) do
    case document do
      {:ok, doc} when is_struct(doc, Document) ->
        if Keyword.get(opts, :load_images, false) do
          BinaryLoader.load_images(doc, opts)
        else
          {:ok, doc}
        end

      other ->
        other
    end
  end

  defp inject_binary_buffer(document, bin_chunk) when is_binary(bin_chunk) do
    case document.buffers do
      [first_buffer | rest] ->
        # GLB format: first buffer is the binary chunk
        updated_buffer = %{first_buffer | data: bin_chunk}
        %{document | buffers: [updated_buffer | rest]}

      [] ->
        document
    end
  end

  defp inject_binary_buffer(document, _), do: document

  defp fetch_url(url) when is_binary(url) do
    fetch_url(String.to_charlist(url))
  end

  defp fetch_url(url) when is_list(url) do
    # Use Erlang's built-in httpc client
    case :httpc.request(:get, {url, []}, [
           timeout: 30_000,
           connect_timeout: 10_000
         ], []) do
      {:ok, {{_, status_code, _}, _headers, body}} when status_code >= 200 and status_code < 300 ->
        {:ok, body}

      {:ok, {{_, status_code, _}, _headers, _body}} ->
        {:error, {:http_error, status_code}}

      {:error, {:connect_failed, reason}} ->
        {:error, {:connection_failed, reason}}

      {:error, reason} ->
        {:error, {:http_request_failed, reason}}
    end
  end

  defp fetch_url(url) do
    {:error, {:invalid_url, url}}
  end

  defp extract_base_uri(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) ->
        base_path = Path.dirname(path)
        URI.to_string(%URI{URI.parse(url) | path: base_path})

      _ ->
        url
    end
  end

  defp detect_content_type(headers, url) do
    # Check Content-Type header first
    content_type =
      headers
      |> Enum.find_value(fn {key, value} ->
        if String.downcase(key) == "content-type", do: value
      end)

    case content_type do
      "application/json" -> :json
      "model/gltf+json" -> :json
      "model/gltf-binary" -> :binary
      "application/octet-stream" -> :binary
      _ -> detect_from_extension(url)
    end
  end

  defp detect_from_extension(url) do
    case Path.extname(url) do
      ".gltf" -> :json
      ".glb" -> :binary
      _ -> :unknown
    end
  end
end
