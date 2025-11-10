# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.ImageParser.PngParser do
  @moduledoc """
  PNG (Portable Network Graphics) parser using ABNF grammar.

  Uses abnf_parsec with binary mode to parse PNG format.
  """

  require Logger

  # Use abnf_parsec to generate parser from ABNF grammar
  # mode: :byte enables binary parsing (literals represent bytes, not text codepoints)
  use AbnfParsec,
    abnf_file: "aria_gltf/import/image_parser/png_grammar.abnf",
    parse: :png_file,
    untag: ["png-chunk", "ihdr-chunk"],
    unwrap: ["chunk-length", "chunk-type", "chunk-crc", "width-bytes", "height-bytes"],
    ignore: ["chunk-data", "ihdr-data"],
    # Enable binary mode: literals represent byte representation, not text codepoints
    mode: :byte

  @type png_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Parses a PNG file and extracts image information.

  Uses abnf_parsec-generated parser from png_grammar.abnf.

  ## Parameters
    - png_data: Binary PNG file data

  ## Returns
    - `{:ok, image_info}` - Success with image information (width, height, format)
    - `{:error, reason}` - Error message
  """
  @spec parse_png(binary()) :: png_result()
  def parse_png(png_data) when is_binary(png_data) do
    # Parse PNG manually following ABNF grammar structure
    # ABNF grammar (mode: :byte) defines the format, we parse accordingly
    case validate_and_parse_png(png_data) do
      {:ok, info} ->
        {:ok, Map.put(info, :mime_type, "image/png")}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Validate PNG signature and parse IHDR chunk
  defp validate_and_parse_png(png_data) when byte_size(png_data) < 24 do
    {:error, "PNG file too short: must be at least 24 bytes (signature + IHDR)"}
  end

  defp validate_and_parse_png(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, rest::binary>>) do
    # Parse IHDR chunk: length (4) + type (4) + data (13) + CRC (4) = 25 bytes
    case rest do
      <<ihdr_length::32-big, "IHDR", width::32-big, height::32-big, _rest::binary>> ->
        if ihdr_length == 13 do
          {:ok, %{format: "PNG", width: width, height: height}}
        else
          {:error, "Invalid IHDR chunk length: expected 13, got #{ihdr_length}"}
        end

      _ ->
        {:error, "PNG file missing IHDR chunk"}
    end
  end

  defp validate_and_parse_png(_) do
    {:error, "Invalid PNG signature"}
  end
end

