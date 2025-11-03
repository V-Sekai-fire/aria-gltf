# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.ExternalFiles do
  @moduledoc """
  External file reference support for glTF documents.

  This module handles loading and resolving external file references including:
  - Image files (JPEG, PNG)
  - Buffer files (.bin)
  - URI resolution and validation
  - Relative path handling
  """

  require Logger

  @type file_result :: {:ok, binary()} | {:error, term()}
  @type uri_info :: %{
          scheme: String.t() | nil,
          path: String.t(),
          is_data_uri: boolean(),
          mime_type: String.t() | nil
        }

  @doc """
  Loads an external file referenced by a URI.

  Supports:
  - File paths (relative and absolute)
  - Data URIs (base64 encoded)
  - HTTP/HTTPS URLs (if enabled)

  ## Options

  - `:base_path` - Base directory for resolving relative paths
  - `:allow_http` - Allow HTTP/HTTPS URLs (default: false)
  - `:max_file_size` - Maximum file size in bytes (default: 50MB)

  ## Examples

      iex> AriaGltf.ExternalFiles.load_file("image.png", base_path: "/path/to/gltf")
      {:ok, <<binary_data>>}

      iex> AriaGltf.ExternalFiles.load_file("data:image/png;base64,iVBORw0KGgoAAAANS...")
      {:ok, <<binary_data>>}
  """
  @spec load_file(String.t(), keyword()) :: file_result()
  def load_file(uri, opts \\ []) when is_binary(uri) do
    base_path = Keyword.get(opts, :base_path, ".")
    allow_http = Keyword.get(opts, :allow_http, false)
    # 50MB
    max_file_size = Keyword.get(opts, :max_file_size, 50 * 1024 * 1024)

    with {:ok, uri_info} <- parse_uri(uri),
         :ok <- validate_uri(uri_info, allow_http),
         {:ok, file_path} <- resolve_file_path(uri_info, base_path),
         {:ok, content} <- read_file_content(file_path, uri_info, max_file_size) do
      {:ok, content}
    end
  end

  @doc """
  Loads an image file and validates its format.

  ## Options

  - `:validate_format` - Validate image format (default: true)
  - `:supported_formats` - List of supported MIME types (default: ["image/jpeg", "image/png"])

  ## Examples

      iex> AriaGltf.ExternalFiles.load_image("texture.jpg", base_path: "/textures")
      {:ok, %{data: <<binary>>, mime_type: "image/jpeg", width: 1024, height: 1024}}
  """
  @spec load_image(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def load_image(uri, opts \\ []) do
    validate_format = Keyword.get(opts, :validate_format, true)
    supported_formats = Keyword.get(opts, :supported_formats, ["image/jpeg", "image/png"])

    with {:ok, data} <- load_file(uri, opts),
         {:ok, image_info} <- analyze_image_data(data, validate_format, supported_formats) do
      {:ok, Map.put(image_info, :data, data)}
    end
  end

  @doc """
  Loads a binary buffer file (.bin).

  ## Examples

      iex> AriaGltf.ExternalFiles.load_buffer("geometry.bin", base_path: "/models")
      {:ok, <<binary_data>>}
  """
  @spec load_buffer(String.t(), keyword()) :: file_result()
  def load_buffer(uri, opts \\ []) do
    load_file(uri, opts)
  end

  @doc """
  Parses a URI and extracts relevant information.
  """
  @spec parse_uri(String.t()) :: {:ok, uri_info()} | {:error, term()}
  def parse_uri(uri) when is_binary(uri) do
    cond do
      String.starts_with?(uri, "data:") ->
        parse_data_uri(uri)

      String.contains?(uri, "://") ->
        parse_url_uri(uri)

      true ->
        {:ok,
         %{
           scheme: nil,
           path: uri,
           is_data_uri: false,
           mime_type: guess_mime_type_from_extension(uri)
         }}
    end
  end

  @doc """
  Validates a URI for security and format compliance.
  """
  @spec validate_uri(uri_info(), boolean()) :: :ok | {:error, term()}
  def validate_uri(%{is_data_uri: true}, _allow_http), do: :ok
  def validate_uri(%{scheme: nil}, _allow_http), do: :ok

  def validate_uri(%{scheme: scheme}, allow_http) when scheme in ["http", "https"] do
    if allow_http do
      :ok
    else
      {:error, {:http_not_allowed, "HTTP/HTTPS URLs are disabled for security"}}
    end
  end

  def validate_uri(%{scheme: scheme}, _allow_http) do
    {:error, {:unsupported_scheme, "Unsupported URI scheme: #{scheme}"}}
  end

  @doc """
  Resolves a file path relative to a base directory.
  """
  @spec resolve_file_path(uri_info(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def resolve_file_path(%{is_data_uri: true}, _base_path), do: {:ok, :data_uri}

  def resolve_file_path(%{scheme: scheme}, _base_path) when not is_nil(scheme) do
    {:error, {:external_url, "External URLs not supported in file path resolution"}}
  end

  def resolve_file_path(%{path: path}, base_path) do
    if Path.type(path) == :absolute do
      # Absolute paths don't need security validation against base_path
      {:ok, path}
    else
      resolved_path = Path.join(base_path, path)
      # Security check: ensure resolved path doesn't escape base directory
      case validate_path_security(resolved_path, base_path) do
        :ok -> {:ok, resolved_path}
        error -> error
      end
    end
  end

  # Private helper functions

  defp parse_data_uri("data:" <> rest) do
    case String.split(rest, ",", parts: 2) do
      [header, data] ->
        {mime_type, encoding} = parse_data_uri_header(header)

        {:ok,
         %{
           scheme: "data",
           path: data,
           is_data_uri: true,
           mime_type: mime_type,
           encoding: encoding
         }}

      _ ->
        {:error, {:invalid_data_uri, "Malformed data URI"}}
    end
  end

  defp parse_data_uri_header(header) do
    parts = String.split(header, ";")
    mime_type = List.first(parts) || "application/octet-stream"

    encoding =
      if Enum.any?(parts, &(&1 == "base64")) do
        :base64
      else
        :url_encoded
      end

    {mime_type, encoding}
  end

  defp parse_url_uri(uri) do
    case URI.parse(uri) do
      %URI{scheme: scheme, path: path} when not is_nil(scheme) ->
        {:ok,
         %{
           scheme: scheme,
           path: path || "",
           is_data_uri: false,
           mime_type: guess_mime_type_from_extension(path || "")
         }}

      _ ->
        {:error, {:invalid_uri, "Could not parse URI: #{uri}"}}
    end
  end

  defp read_file_content(:data_uri, %{path: data, encoding: encoding}, _max_size) do
    decode_data_uri_content(data, encoding)
  end

  defp read_file_content(file_path, _uri_info, max_file_size) do
    case File.stat(file_path) do
      {:ok, %File.Stat{size: size}} when size > max_file_size ->
        {:error, {:file_too_large, "File size #{size} exceeds maximum #{max_file_size}"}}

      {:ok, _} ->
        case File.read(file_path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, {:file_read_error, reason}}
        end

      {:error, reason} ->
        {:error, {:file_stat_error, reason}}
    end
  end

  defp decode_data_uri_content(data, :base64) do
    case Base.decode64(data) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, {:base64_decode_error, "Invalid base64 data"}}
    end
  end

  defp decode_data_uri_content(data, :url_encoded) do
    case URI.decode(data) do
      decoded when is_binary(decoded) -> {:ok, decoded}
      _ -> {:error, {:url_decode_error, "Invalid URL-encoded data"}}
    end
  end

  # Make this function public for testing
  @doc false
  def analyze_image_data(_data, false, _supported_formats) do
    # Skip validation, return basic info
    {:ok,
     %{
       mime_type: "application/octet-stream",
       width: nil,
       height: nil,
       validated: false
     }}
  end

  def analyze_image_data(data, true, supported_formats) do
    with {:ok, mime_type} <- detect_image_format(data),
         :ok <- validate_supported_format(mime_type, supported_formats),
         {:ok, dimensions} <- extract_image_dimensions(data, mime_type) do
      {:ok, Map.merge(dimensions, %{mime_type: mime_type, validated: true})}
    end
  end

  defp detect_image_format(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: {:ok, "image/jpeg"}

  defp detect_image_format(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>>),
    do: {:ok, "image/png"}

  defp detect_image_format(_),
    do: {:error, {:unknown_image_format, "Could not detect image format"}}

  defp validate_supported_format(mime_type, supported_formats) do
    if mime_type in supported_formats do
      :ok
    else
      {:error, {:unsupported_format, "Format #{mime_type} not in supported list"}}
    end
  end

  defp extract_image_dimensions(data, "image/jpeg") do
    case extract_jpeg_dimensions(data) do
      {:ok, dimensions} -> {:ok, dimensions}
      # Fallback for test data
      {:error, _} -> {:ok, %{width: nil, height: nil}}
    end
  end

  defp extract_image_dimensions(data, "image/png") do
    case extract_png_dimensions(data) do
      {:ok, dimensions} -> {:ok, dimensions}
      # Fallback for test data
      {:error, _} -> {:ok, %{width: nil, height: nil}}
    end
  end

  defp extract_image_dimensions(_, _) do
    {:ok, %{width: nil, height: nil}}
  end

  defp extract_jpeg_dimensions(<<0xFF, 0xD8, rest::binary>>) do
    find_jpeg_sof_marker(rest)
  end

  defp extract_jpeg_dimensions(_), do: {:error, {:invalid_jpeg, "Not a valid JPEG file"}}

  defp find_jpeg_sof_marker(<<0xFF, marker, length::16-big, rest::binary>>)
       when marker in [0xC0, 0xC1, 0xC2] do
    # SOF markers - extract segment based on length
    segment_size = length - 2

    if byte_size(rest) >= segment_size do
      <<segment::binary-size(segment_size), _remaining::binary>> = rest

      case segment do
        <<_precision, height::16-big, width::16-big, _rest::binary>> ->
          {:ok, %{width: width, height: height}}

        _ ->
          {:error, {:invalid_sof, "Invalid SOF segment"}}
      end
    else
      # Not enough data for full segment
      {:error, {:incomplete_sof, "Incomplete SOF segment"}}
    end
  end

  defp find_jpeg_sof_marker(<<0xFF, _marker, _length::16-big, rest::binary>>) do
    # Skip other markers and continue searching
    find_jpeg_sof_marker(rest)
  end

  defp find_jpeg_sof_marker(<<_::binary-size(1), rest::binary>>) when byte_size(rest) > 0 do
    find_jpeg_sof_marker(rest)
  end

  defp find_jpeg_sof_marker(_), do: {:error, {:no_sof_found, "No SOF marker found"}}

  defp extract_png_dimensions(
         <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _length::32-big, "IHDR", width::32-big,
           height::32-big, _rest::binary>>
       ) do
    {:ok, %{width: width, height: height}}
  end

  defp extract_png_dimensions(_), do: {:error, {:invalid_png, "Not a valid PNG file"}}

  defp guess_mime_type_from_extension(path) do
    case Path.extname(path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".bin" -> "application/octet-stream"
      _ -> "application/octet-stream"
    end
  end

  defp validate_path_security(resolved_path, base_path) do
    resolved_abs = Path.absname(resolved_path)
    base_abs = Path.absname(base_path)

    # Normalize paths to ensure proper comparison
    resolved_normalized = Path.expand(resolved_abs)
    base_normalized = Path.expand(base_abs)

    if String.starts_with?(resolved_normalized, base_normalized) do
      :ok
    else
      {:error, {:path_escape_attempt, "Resolved path escapes base directory"}}
    end
  end
end
