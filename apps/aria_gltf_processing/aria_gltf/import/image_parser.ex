# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.ImageParser do
  @moduledoc """
  Image format parser using ABNF grammar for format validation and parsing.

  Supports PNG, JPEG, and WebP formats using abnf_parsec with binary mode.
  """

  require Logger

  alias AriaGltf.Import.ImageParser.{PngParser, JpegParser, WebpParser}

  @type image_result :: {:ok, map()} | {:error, String.t()}
  @type image_info :: %{
          format: String.t(),
          width: non_neg_integer() | nil,
          height: non_neg_integer() | nil,
          mime_type: String.t()
        }

  @doc """
  Detects and parses image format from binary data.

  ## Parameters
    - data: Binary image data

  ## Returns
    - `{:ok, image_info}` - Success with image information
    - `{:error, reason}` - Error message

  ## Supported Formats
    - PNG (image/png)
    - JPEG (image/jpeg)
    - WebP (image/webp)
  """
  @spec parse_image(binary()) :: image_result()
  def parse_image(data) when is_binary(data) do
    cond do
      is_png?(data) ->
        PngParser.parse_png(data)

      is_jpeg?(data) ->
        JpegParser.parse_jpeg(data)

      is_webp?(data) ->
        WebpParser.parse_webp(data)

      true ->
        {:error, "Unknown image format"}
    end
  end

  @doc """
  Detects image format from binary data.

  ## Parameters
    - data: Binary image data

  ## Returns
    - `{:ok, mime_type}` - Success with MIME type
    - `{:error, reason}` - Error message
  """
  @spec detect_format(binary()) :: {:ok, String.t()} | {:error, String.t()}
  def detect_format(data) when is_binary(data) do
    cond do
      is_png?(data) -> {:ok, "image/png"}
      is_jpeg?(data) -> {:ok, "image/jpeg"}
      is_webp?(data) -> {:ok, "image/webp"}
      true -> {:error, "Unknown image format"}
    end
  end

  # Quick format detection
  defp is_png?(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>), do: true
  defp is_png?(_), do: false

  defp is_jpeg?(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: true
  defp is_jpeg?(_), do: false

  defp is_webp?(<<"RIFF", _::binary-size(4), "WEBP", _rest::binary>>), do: true
  defp is_webp?(_), do: false
end

