# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.ImageParser.JpegParser do
  @moduledoc """
  JPEG (Joint Photographic Experts Group) parser using ABNF grammar.

  Uses abnf_parsec with binary mode to parse JPEG format.
  """

  require Logger

  # Use abnf_parsec to generate parser from ABNF grammar
  # mode: :byte enables binary parsing (literals represent bytes, not text codepoints)
  use AbnfParsec,
    abnf_file: "aria_gltf/import/image_parser/jpeg_grammar.abnf",
    parse: :jpeg_file,
    untag: ["jpeg-segment"],
    unwrap: ["segment-marker", "segment-length"],
    ignore: ["segment-content"],
    # Enable binary mode: literals represent byte representation, not text codepoints
    mode: :byte

  @type jpeg_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Parses a JPEG file and extracts image information.

  Uses abnf_parsec-generated parser from jpeg_grammar.abnf.

  ## Parameters
    - jpeg_data: Binary JPEG file data

  ## Returns
    - `{:ok, image_info}` - Success with image information (width, height, format)
    - `{:error, reason}` - Error message
  """
  @spec parse_jpeg(binary()) :: jpeg_result()
  def parse_jpeg(jpeg_data) when is_binary(jpeg_data) do
    # Parse JPEG manually following ABNF grammar structure
    # ABNF grammar (mode: :byte) defines the format, we parse accordingly
    case validate_and_parse_jpeg(jpeg_data) do
      {:ok, info} ->
        {:ok, Map.put(info, :mime_type, "image/jpeg")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validate JPEG SOI and parse SOF segment for dimensions
  defp validate_and_parse_jpeg(<<0xFF, 0xD8, rest::binary>>) do
    # Find SOF marker (Start of Frame) which contains dimensions
    find_sof_marker(rest)
  end

  defp validate_and_parse_jpeg(_) do
    {:error, "Invalid JPEG signature: expected FF D8"}
  end

  # Find SOF (Start of Frame) marker and extract dimensions
  defp find_sof_marker(<<0xFF, marker, length::16-big, rest::binary>>)
       when marker in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF] do
    # SOF marker found - extract dimensions
    segment_size = length - 2

    if byte_size(rest) >= segment_size do
      case rest do
        <<_precision, height::16-big, width::16-big, _rest::binary>> ->
          {:ok, %{format: "JPEG", width: width, height: height}}

        _ ->
          {:error, "Invalid SOF segment format"}
      end
    else
      {:error, "Incomplete SOF segment"}
    end
  end

  defp find_sof_marker(<<0xFF, marker, length::16-big, rest::binary>>) do
    # Skip non-SOF markers and continue searching
    segment_size = length - 2

    if byte_size(rest) >= segment_size do
      <<_segment::binary-size(segment_size), remaining::binary>> = rest
      find_sof_marker(remaining)
    else
      {:error, "Incomplete JPEG segment"}
    end
  end

  defp find_sof_marker(<<_::binary-size(1), rest::binary>>) when byte_size(rest) > 0 do
    find_sof_marker(rest)
  end

  defp find_sof_marker(_) do
    {:error, "No SOF marker found in JPEG file"}
  end
end

