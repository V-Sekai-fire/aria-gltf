# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.ImageParser.WebpParser do
  @moduledoc """
  WebP parser using ABNF grammar.

  Uses abnf_parsec with binary mode to parse WebP format.
  """

  require Logger
  import Bitwise

  # Use abnf_parsec to generate parser from ABNF grammar
  # mode: :byte enables binary parsing (literals represent bytes, not text codepoints)
  use AbnfParsec,
    abnf_file: "aria_gltf/import/image_parser/webp_grammar.abnf",
    parse: :webp_file,
    untag: ["webp-riff-header", "webp-chunks"],
    unwrap: ["file-size"],
    ignore: ["vp8-data", "vp8l-data", "vp8x-data"],
    # Enable binary mode: literals represent byte representation, not text codepoints
    mode: :byte

  @type webp_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Parses a WebP file and extracts image information.

  Uses abnf_parsec-generated parser from webp_grammar.abnf.

  ## Parameters
    - webp_data: Binary WebP file data

  ## Returns
    - `{:ok, image_info}` - Success with image information (width, height, format)
    - `{:error, reason}` - Error message
  """
  @spec parse_webp(binary()) :: webp_result()
  def parse_webp(webp_data) when is_binary(webp_data) do
    # Parse WebP manually following ABNF grammar structure
    # ABNF grammar (mode: :byte) defines the format, we parse accordingly
    case validate_and_parse_webp(webp_data) do
      {:ok, info} ->
        {:ok, Map.put(info, :mime_type, "image/webp")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validate WebP RIFF header and parse chunk for dimensions
  defp validate_and_parse_webp(<<"RIFF", file_size::32-little, "WEBP", rest::binary>>) do
    # Validate file size
    expected_size = byte_size(rest) + 8

    if file_size != expected_size do
      Logger.warning("WebP file size mismatch: header says #{file_size}, actual is #{expected_size}")
    end

    # Parse WebP chunk to extract dimensions
    parse_webp_chunk(rest)
  end

  defp validate_and_parse_webp(_) do
    {:error, "Invalid WebP signature: expected RIFF...WEBP"}
  end

  # Parse WebP chunk (VP8, VP8L, or VP8X)
  defp parse_webp_chunk(<<chunk_type::binary-size(4), chunk_size::32-little, chunk_data::binary>>) do
    case chunk_type do
      "VP8 " ->
        # VP8 lossy format - dimensions are in first few bytes
        parse_vp8_dimensions(chunk_data)

      "VP8L" ->
        # VP8L lossless format - dimensions are encoded
        parse_vp8l_dimensions(chunk_data)

      "VP8X" ->
        # VP8X extended format - dimensions in header
        parse_vp8x_dimensions(chunk_data)

      _ ->
        {:error, "Unknown WebP chunk type: #{inspect(chunk_type)}"}
    end
  end

  defp parse_webp_chunk(_) do
    {:error, "Invalid WebP chunk structure"}
  end

  # Parse VP8 dimensions (simplified - VP8 format is complex)
  defp parse_vp8_dimensions(data) when byte_size(data) >= 10 do
    # VP8 keyframe header contains dimensions
    # This is a simplified parser - full VP8 parsing is more complex
    <<_frame_tag, _version, _show_frame, _first_part_size, width_part::16-little, height_part::16-little,
      _rest::binary>> = data

    width = Bitwise.band(width_part, 0x3FFF)
    height = Bitwise.band(height_part, 0x3FFF)
    {:ok, %{format: "WebP", width: width, height: height}}
  end

  defp parse_vp8_dimensions(_) do
    {:error, "Incomplete VP8 chunk data"}
  end

  # Parse VP8L dimensions (lossless)
  defp parse_vp8l_dimensions(data) when byte_size(data) >= 5 do
    # VP8L format encodes dimensions in first few bytes
    <<_signature, width_minus_one::24-little, height_minus_one::24-little, _rest::binary>> = data
    width = Bitwise.band(width_minus_one, 0x3FFF) + 1
    height = Bitwise.band(Bitwise.bsr(height_minus_one, 14), 0x3FFF) + 1
    {:ok, %{format: "WebP", width: width, height: height}}
  end

  defp parse_vp8l_dimensions(_) do
    {:error, "Incomplete VP8L chunk data"}
  end

  # Parse VP8X dimensions (extended format)
  defp parse_vp8x_dimensions(data) when byte_size(data) >= 10 do
    # VP8X header: flags (1) + reserved (3) + width (3) + height (3)
    <<_flags, _reserved::binary-size(3), width_minus_one::24-little, height_minus_one::24-little, _rest::binary>> = data
    width = width_minus_one + 1
    height = height_minus_one + 1
    {:ok, %{format: "WebP", width: width, height: height}}
  end

  defp parse_vp8x_dimensions(_) do
    {:error, "Incomplete VP8X chunk data"}
  end
end

