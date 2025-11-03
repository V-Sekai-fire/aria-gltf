# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Buffer do
  @moduledoc """
  A buffer points to binary geometry, animation, or skins.

  From glTF 2.0 specification section 5.10:
  A buffer is arbitrary data stored as a binary blob. The buffer MAY contain any combination of
  geometry, animation, skins, and images.
  """

  @type t :: %__MODULE__{
          uri: String.t() | nil,
          byte_length: non_neg_integer(),
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil,
          data: binary() | nil
        }

  @enforce_keys [:byte_length]
  defstruct [
    :uri,
    :byte_length,
    :name,
    :extensions,
    :extras,
    :data
  ]

  @doc """
  Creates a new Buffer struct.

  ## Parameters
  - `byte_length`: The length of the buffer in bytes (required)
  - `uri`: The URI (or IRI) of the buffer (optional)
  - `name`: The user-defined name of this object (optional)
  - `extensions`: JSON object with extension-specific objects (optional)
  - `extras`: Application-specific data (optional)

  ## Examples

      iex> AriaGltf.Buffer.new(1024)
      %AriaGltf.Buffer{byte_length: 1024, uri: nil, name: nil, extensions: nil, extras: nil}

      iex> AriaGltf.Buffer.new(2048, uri: "geometry.bin", name: "Main Buffer")
      %AriaGltf.Buffer{byte_length: 2048, uri: "geometry.bin", name: "Main Buffer", extensions: nil, extras: nil}
  """
  @spec new(non_neg_integer(), keyword()) :: t()
  def new(byte_length, opts \\ []) when is_integer(byte_length) and byte_length >= 1 do
    %__MODULE__{
      byte_length: byte_length,
      uri: Keyword.get(opts, :uri),
      name: Keyword.get(opts, :name),
      extensions: Keyword.get(opts, :extensions),
      extras: Keyword.get(opts, :extras)
    }
  end

  @doc """
  Creates a new buffer with byte_length, uri, and options.
  """
  @spec new(non_neg_integer(), String.t(), map()) :: t()
  def new(byte_length, uri, options)
      when is_integer(byte_length) and byte_length >= 1 and is_binary(uri) and is_map(options) do
    %__MODULE__{
      byte_length: byte_length,
      uri: uri,
      name: Map.get(options, :name),
      extensions: Map.get(options, :extensions),
      extras: Map.get(options, :extras)
    }
  end

  @doc """
  Validates a Buffer struct according to glTF 2.0 specification.

  ## Validation Rules
  - byte_length must be >= 1
  - uri must be a valid string if present
  - For GLB-stored buffers, uri should be undefined and it must be the first buffer

  ## Examples

      iex> buffer = AriaGltf.Buffer.new(1024)
      iex> AriaGltf.Buffer.validate(buffer)
      :ok

      iex> invalid_buffer = %AriaGltf.Buffer{byte_length: 0}
      iex> AriaGltf.Buffer.validate(invalid_buffer)
      {:error, "byte_length must be >= 1"}
  """
  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = buffer) do
    with :ok <- validate_byte_length(buffer.byte_length),
         :ok <- validate_uri(buffer.uri) do
      :ok
    end
  end

  defp validate_byte_length(byte_length) when is_integer(byte_length) and byte_length >= 1,
    do: :ok

  defp validate_byte_length(_), do: {:error, "byte_length must be >= 1"}

  defp validate_uri(nil), do: :ok
  defp validate_uri(uri) when is_binary(uri), do: :ok
  defp validate_uri(_), do: {:error, "uri must be a string"}

  @doc """
  Converts a Buffer struct to a map suitable for JSON encoding.

  ## Examples

      iex> buffer = AriaGltf.Buffer.new(1024, uri: "data.bin", name: "Buffer")
      iex> AriaGltf.Buffer.to_map(buffer)
      %{
        "byteLength" => 1024,
        "uri" => "data.bin",
        "name" => "Buffer"
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = buffer) do
    map = %{}
    map = if buffer.byte_length, do: Map.put(map, "byteLength", buffer.byte_length), else: map
    map = if buffer.uri, do: Map.put(map, "uri", buffer.uri), else: map
    map = if buffer.name, do: Map.put(map, "name", buffer.name), else: map
    map = if buffer.extensions, do: Map.put(map, "extensions", buffer.extensions), else: map
    map = if buffer.extras, do: Map.put(map, "extras", buffer.extras), else: map
    map
  end

  @doc """
  Creates a Buffer struct from a map (typically from JSON parsing).

  ## Examples

      iex> map = %{"byteLength" => 1024, "uri" => "data.bin"}
      iex> AriaGltf.Buffer.from_map(map)
      {:ok, %AriaGltf.Buffer{byte_length: 1024, uri: "data.bin", name: nil, extensions: nil, extras: nil}}

      iex> invalid_map = %{"uri" => "data.bin"}
      iex> AriaGltf.Buffer.from_map(invalid_map)
      {:error, "Missing required field: byteLength"}
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(map) when is_map(map) do
    case Map.get(map, "byteLength") do
      nil -> {:error, "Missing required field: byteLength"}
      byte_length ->
        buffer = %__MODULE__{
          byte_length: byte_length,
          uri: Map.get(map, "uri"),
          name: Map.get(map, "name"),
          extensions: Map.get(map, "extensions"),
          extras: Map.get(map, "extras")
        }

        case validate(buffer) do
          :ok -> {:ok, buffer}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Checks if this buffer is a GLB-stored buffer (has no URI).

  GLB-stored buffers are embedded in the GLB file format and don't have external URIs.

  ## Examples

      iex> buffer = AriaGltf.Buffer.new(1024)
      iex> AriaGltf.Buffer.glb_stored?(buffer)
      true

      iex> buffer = AriaGltf.Buffer.new(1024, uri: "data.bin")
      iex> AriaGltf.Buffer.glb_stored?(buffer)
      false
  """
  @spec glb_stored?(t()) :: boolean()
  def glb_stored?(%__MODULE__{uri: nil}), do: true
  def glb_stored?(%__MODULE__{}), do: false

  @doc """
  Checks if this buffer uses a data URI.

  ## Examples

      iex> buffer = AriaGltf.Buffer.new(1024, uri: "data:application/octet-stream;base64,SGVsbG8=")
      iex> AriaGltf.Buffer.data_uri?(buffer)
      true

      iex> buffer = AriaGltf.Buffer.new(1024, uri: "data.bin")
      iex> AriaGltf.Buffer.data_uri?(buffer)
      false
  """
  @spec data_uri?(t()) :: boolean()
  def data_uri?(%__MODULE__{uri: "data:" <> _}), do: true
  def data_uri?(%__MODULE__{}), do: false

  @doc """
  Creates a Buffer struct from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) do
    case from_map(json) do
      {:ok, buffer} -> buffer
      {:error, _reason} -> raise ArgumentError, "Invalid buffer JSON"
    end
  end

  @doc """
  Converts a Buffer struct to JSON-compatible map.
  """
  @spec to_json(t()) :: map()
  def to_json(buffer), do: to_map(buffer)
end
