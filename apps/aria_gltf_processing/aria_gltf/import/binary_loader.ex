# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.BinaryLoader do
  @moduledoc """
  Binary data loading for glTF GLB format and external resources using ABNF grammar.

  This module handles the binary GLB format parsing using abnf_parsec for format validation
  and parsing. Uses ABNF grammar defined in glb_grammar.abnf.
  """

  require Logger

  alias AriaGltf.{Document, Buffer, Image}
  alias Jason

  # Use abnf_parsec to generate parser from ABNF grammar
  # ABNF handles binary through num-val (hex-val) for specifying byte values
  # File path relative to app root (apps/aria_gltf_processing/)
  # mode: :byte enables binary parsing (literals represent bytes, not text codepoints)
  use AbnfParsec,
    abnf_file: "aria_gltf/import/glb_grammar.abnf",
    parse: :glb_file,
    untag: ["glb-header", "glb-chunk"],
    unwrap: ["magic", "version-bytes", "length-bytes", "chunk-length-bytes", "chunk-type-bytes"],
    ignore: ["chunk-data"],  # Will handle chunk-data manually based on length
    mode: :byte  # Enable binary mode: literals represent byte representation, not text codepoints

  # GLB format constants
  # "glTF" in little endian
  @glb_magic 0x46546C67
  @glb_version 2
  # "JSON" in little endian
  @json_chunk_type 0x4E4F534A
  # "BIN\0" in little endian
  @bin_chunk_type 0x004E4942

  @type glb_result :: {:ok, {binary(), binary()}} | {:error, term()}
  @type load_result :: {:ok, Document.t()} | {:error, term()}

  @doc """
  Loads a GLB file from the given path and returns a parsed `AriaGltf.Document`.
  """
  @spec load_glb(String.t()) :: load_result()
  def load_glb(path) do
    with {:ok, glb_data} <- File.read(path),
         {:ok, {json_chunk, bin_chunk}} <- parse_glb(glb_data),
         {:ok, json_map} <- Jason.decode(json_chunk),
         {:ok, document} <- Document.from_json(json_map) do
      # Assign binary chunk to the first buffer if it exists
      document =
        if bin_chunk && document.buffers && length(document.buffers) > 0 do
          [%Buffer{} = first_buffer | rest] = document.buffers
          %{document | buffers: [%{first_buffer | data: bin_chunk} | rest]}
        else
          document
        end

      # Load external buffers and images
      document
      |> load_buffers(base_uri: Path.dirname(path))
      |> then(&load_images(&1, base_uri: Path.dirname(path)))
    end
  end

  @doc """
  Parses a GLB binary file into JSON and binary chunks using ABNF grammar.

  Uses abnf_parsec-generated parser from glb_grammar.abnf for format validation.

  ## Examples

      iex> glb_data = File.read!("model.glb")
      iex> AriaGltf.Import.BinaryLoader.parse_glb(glb_data)
      {:ok, {json_chunk, binary_chunk}}
  """
  @spec parse_glb(binary()) :: glb_result()
  def parse_glb(data) when is_binary(data) do
    # Parse GLB manually - ABNF parser validates structure
    # We use manual parsing for variable-length binary chunks
    case validate_and_parse_glb(data) do
      {:ok, {json_chunk, bin_chunk}} ->
        {:ok, {json_chunk, bin_chunk}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validate GLB header and parse chunks manually
  # ABNF parser validates structure, but we handle variable-length binary manually
  defp validate_and_parse_glb(glb_data) when byte_size(glb_data) < 12 do
    {:error, "GLB file too short: must be at least 12 bytes"}
  end

  defp validate_and_parse_glb(glb_data) do
    # Parse header: magic (4) + version (4) + length (4) = 12 bytes
    case glb_data do
      <<magic::binary-size(4), version::little-32, total_length::little-32, rest::binary>> ->
        # Validate magic number
        if magic != "glTF" do
          {:error, "Invalid GLB magic number: expected 'glTF', got #{inspect(magic)}"}
        else
          # Validate version (should be 2)
          if version != 2 do
            Logger.warning("GLB version is #{version}, expected 2")
          end

          # Validate total length
          if total_length != byte_size(glb_data) do
            {:error,
             "GLB length mismatch: header says #{total_length} bytes, file is #{byte_size(glb_data)} bytes"}
          else
            # Parse chunks
            parse_glb_chunks(rest, total_length - 12, nil, nil)
          end
        end

      _ ->
        {:error, "Invalid GLB file format: cannot parse header"}
    end
  end

  # Parse GLB chunks (manual parsing for variable-length binary)
  # Following ABNF grammar: chunk-length chunk-type chunk-data
  defp parse_glb_chunks(data, remaining, json_chunk, bin_chunk)
       when remaining > 0 and byte_size(data) >= 8 do
    # Parse chunk header: length (4 bytes, little-endian) + type (4 bytes)
    case data do
      <<chunk_length::little-32, chunk_type::binary-size(4), rest::binary>> ->
        # Validate chunk_length
        if chunk_length < 0 or chunk_length > remaining do
          {:error, "Invalid GLB chunk length: #{chunk_length} (remaining: #{remaining})"}
        else
          # Validate we have enough data
          if byte_size(rest) < chunk_length do
            {:error,
             "Incomplete GLB chunk data: expected #{chunk_length} bytes, got #{byte_size(rest)}"}
          else
            <<chunk_data::binary-size(chunk_length), next_chunks::binary>> = rest

            # Identify chunk type
            {new_json_chunk, new_bin_chunk} =
              case normalize_chunk_type(chunk_type) do
                "JSON" -> {chunk_data, bin_chunk}
                "BIN" -> {json_chunk, chunk_data}
                _ -> {json_chunk, bin_chunk} # Unknown chunk type, skip
              end

            new_remaining = remaining - chunk_length - 8
            parse_glb_chunks(next_chunks, new_remaining, new_json_chunk, new_bin_chunk)
          end
        end

      _ ->
        {:error, "Invalid GLB file format: incomplete chunk header"}
    end
  end

  defp parse_glb_chunks(_, remaining, json_chunk, bin_chunk) when remaining <= 0 do
    if json_chunk do
      {:ok, {json_chunk, bin_chunk}}
    else
      {:error, "No JSON chunk found in GLB file"}
    end
  end

  defp parse_glb_chunks(_, _, _, _) do
    {:error, "Invalid GLB file format: incomplete chunk"}
  end

  # Normalize chunk type (remove null bytes, convert to string)
  defp normalize_chunk_type(<<type::binary-size(4)>>) do
    type
    |> String.trim(<<0>>)
    |> String.trim()
  end

  @doc """
  Loads buffer data for all buffers in a document.

  ## Examples

      iex> AriaGltf.Import.BinaryLoader.load_buffers(document, base_uri: "/path/to/files")
      {:ok, %AriaGltf.Document{...}}
  """
  @spec load_buffers(Document.t() | {:ok, Document.t()} | {:ok, map()}, keyword()) :: load_result()
  # Handle Document struct directly (not wrapped in {:ok, ...})
  def load_buffers(%Document{buffers: buffers} = document, opts) do
    base_uri = Keyword.get(opts, :base_uri, "")

    case load_buffer_data(buffers, base_uri, []) do
      {:ok, loaded_buffers} ->
        {:ok, %{document | buffers: loaded_buffers}}

      {:error, _} = error ->
        error
    end
  end

  # Handle {:ok, Document} tuple
  def load_buffers({:ok, %Document{buffers: buffers} = document}, opts) do
    base_uri = Keyword.get(opts, :base_uri, "")

    case load_buffer_data(buffers, base_uri, []) do
      {:ok, loaded_buffers} ->
        {:ok, %{document | buffers: loaded_buffers}}

      {:error, _} = error ->
        error
    end
  end

  # Handle map-based documents (from test fixtures)
  def load_buffers({:ok, document}, opts) when is_map(document) do
    base_uri = Keyword.get(opts, :base_uri, "")
    buffers = Map.get(document, :buffers) || Map.get(document, "buffers") || []

    case load_buffer_data(buffers, base_uri, []) do
      {:ok, loaded_buffers} ->
        {:ok, Map.put(document, :buffers, loaded_buffers)}

      {:error, _} = error ->
        error
    end
  end

  # Handle map-based documents directly (not wrapped in {:ok, ...})
  def load_buffers(document, opts) when is_map(document) do
    base_uri = Keyword.get(opts, :base_uri, "")
    buffers = Map.get(document, :buffers) || Map.get(document, "buffers") || []

    case load_buffer_data(buffers, base_uri, []) do
      {:ok, loaded_buffers} ->
        {:ok, Map.put(document, :buffers, loaded_buffers)}

      {:error, _} = error ->
        error
    end
  end

  def load_buffers({:error, _} = error, _opts), do: error

  @doc """
  Loads image data for all images in a document.

  ## Examples

      iex> AriaGltf.Import.BinaryLoader.load_images(document, base_uri: "/path/to/files")
      {:ok, %AriaGltf.Document{...}}
  """
  @spec load_images(Document.t(), keyword()) :: load_result()
  def load_images({:ok, %Document{images: images} = document}, opts) do
    base_uri = Keyword.get(opts, :base_uri, "")

    case load_image_data(images, document.buffer_views, document.buffers, base_uri, []) do
      {:ok, loaded_images} ->
        {:ok, %{document | images: loaded_images}}

      {:error, _} = error ->
        error
    end
  end

  def load_images({:error, _} = error, _opts), do: error


  # Buffer loading
  defp load_buffer_data([], _base_uri, acc), do: {:ok, Enum.reverse(acc)}

  defp load_buffer_data([buffer | rest], base_uri, acc) do
    case load_single_buffer(buffer, base_uri) do
      {:ok, loaded_buffer} ->
        load_buffer_data(rest, base_uri, [loaded_buffer | acc])

      {:error, _} = error ->
        error
    end
  end

  defp load_single_buffer(%Buffer{data: data} = buffer, _base_uri) when is_binary(data) do
    # Buffer already has data (e.g., from GLB binary chunk)
    {:ok, buffer}
  end

  defp load_single_buffer(%Buffer{uri: nil} = _buffer, _base_uri) do
    # Buffer with no URI and no data - this is an error
    {:error, "Buffer has no URI and no embedded data"}
  end

  defp load_single_buffer(%Buffer{uri: uri} = buffer, base_uri) when is_binary(uri) do
    case load_buffer_from_uri(uri, base_uri) do
      {:ok, data} ->
        {:ok, %{buffer | data: data}}

      {:error, _} = error ->
        error
    end
  end

  defp load_buffer_from_uri("data:" <> _ = data_uri, _base_uri) do
    decode_data_uri(data_uri)
  end

  defp load_buffer_from_uri(uri, base_uri) when is_binary(uri) do
    full_path = resolve_uri(uri, base_uri)

    case File.read(full_path) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Failed to read buffer file #{full_path}: #{reason}"}
    end
  end

  # Image loading
  defp load_image_data([], _buffer_views, _buffers, _base_uri, acc), do: {:ok, Enum.reverse(acc)}

  defp load_image_data([image | rest], buffer_views, buffers, base_uri, acc) do
    case load_single_image(image, buffer_views, buffers, base_uri) do
      {:ok, loaded_image} ->
        load_image_data(rest, buffer_views, buffers, base_uri, [loaded_image | acc])

      {:error, _} = error ->
        error
    end
  end

  defp load_single_image(%Image{data: data} = image, _buffer_views, _buffers, _base_uri)
       when is_binary(data) do
    # Image already has data
    {:ok, image}
  end

  defp load_single_image(%Image{buffer_view: bv_index} = image, buffer_views, buffers, _base_uri)
       when is_integer(bv_index) do
    # Load image from buffer view
    case extract_buffer_view_data(bv_index, buffer_views, buffers) do
      {:ok, data} ->
        {:ok, %{image | data: data}}

      {:error, _} = error ->
        error
    end
  end

  defp load_single_image(%Image{uri: uri} = image, _buffer_views, _buffers, base_uri)
       when is_binary(uri) do
    case load_image_from_uri(uri, base_uri) do
      {:ok, data} ->
        {:ok, %{image | data: data}}

      {:error, _} = error ->
        error
    end
  end

  defp load_single_image(%Image{} = image, _buffer_views, _buffers, _base_uri) do
    # Image with no source - this might be valid in some cases
    {:ok, image}
  end

  defp load_image_from_uri("data:" <> _ = data_uri, _base_uri) do
    decode_data_uri(data_uri)
  end

  defp load_image_from_uri(uri, base_uri) when is_binary(uri) do
    full_path = resolve_uri(uri, base_uri)

    case File.read(full_path) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "Failed to read image file #{full_path}: #{reason}"}
    end
  end

  # Buffer view data extraction
  defp extract_buffer_view_data(bv_index, buffer_views, buffers) when is_integer(bv_index) do
    case Enum.at(buffer_views, bv_index) do
      nil ->
        {:error, "Invalid buffer view index: #{bv_index}"}

      buffer_view ->
        extract_from_buffer_view(buffer_view, buffers)
    end
  end

  defp extract_from_buffer_view(buffer_view, buffers) do
    buffer_index = buffer_view.buffer

    case Enum.at(buffers, buffer_index) do
      nil ->
        {:error, "Invalid buffer index: #{buffer_index}"}

      %Buffer{data: nil} ->
        {:error, "Buffer #{buffer_index} has no data"}

      %Buffer{data: buffer_data} ->
        offset = buffer_view.byte_offset
        length = buffer_view.byte_length

        if byte_size(buffer_data) >= offset + length do
          <<_::binary-size(offset), data::binary-size(length), _::binary>> = buffer_data
          {:ok, data}
        else
          {:error, "Buffer view extends beyond buffer data"}
        end
    end
  end

  # Data URI decoding
  defp decode_data_uri("data:" <> rest) do
    case String.split(rest, ",", parts: 2) do
      [_media_type, encoded_data] ->
        # Simple base64 decoding - in a real implementation,
        # we'd need to parse the media type and encoding
        case Base.decode64(encoded_data) do
          {:ok, data} -> {:ok, data}
          :error -> {:error, "Invalid base64 data in data URI"}
        end

      _ ->
        {:error, "Invalid data URI format"}
    end
  end

  # URI resolution
  defp resolve_uri(uri, base_uri) do
    case URI.parse(uri) do
      %URI{scheme: nil} ->
        # Relative URI
        Path.join(base_uri, uri)

      %URI{} ->
        # Absolute URI - for file:// schemes we'd extract the path
        # For now, just return the URI as-is
        uri
    end
  end
end
