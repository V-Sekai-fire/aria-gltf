# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Image do
  @moduledoc """
  Image data used by a texture.
  """

  @type t :: %__MODULE__{
          uri: String.t() | nil,
          mime_type: String.t() | nil,
          buffer_view: non_neg_integer() | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil,
          data: binary() | nil
        }

  defstruct [
    :uri,
    :mime_type,
    :buffer_view,
    :name,
    :extensions,
    :extras,
    :data
  ]

  @doc """
  Creates a new image.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new image with URI or buffer and options.
  """
  def new(uri_or_buffer, options \\ %{}) do
    if is_binary(uri_or_buffer) do
      %__MODULE__{
        uri: uri_or_buffer,
        name: Map.get(options, :name),
        mime_type: Map.get(options, :mime_type),
        extensions: Map.get(options, :extensions),
        extras: Map.get(options, :extras)
      }
    else
      %__MODULE__{
        buffer_view: uri_or_buffer,
        name: Map.get(options, :name),
        mime_type: Map.get(options, :mime_type),
        extensions: Map.get(options, :extensions),
        extras: Map.get(options, :extras)
      }
    end
  end

  @doc """
  Creates an Image struct from JSON data.
  """
  def from_json(json) when is_map(json) do
    %__MODULE__{
      uri: Map.get(json, "uri"),
      mime_type: Map.get(json, "mimeType"),
      buffer_view: Map.get(json, "bufferView"),
      name: Map.get(json, "name"),
      extensions: Map.get(json, "extensions"),
      extras: Map.get(json, "extras")
    }
  end

  @doc """
  Converts an Image struct to JSON-compatible map.
  """
  def to_json(%__MODULE__{} = image) do
    %{}
    |> put_if_present("uri", image.uri)
    |> put_if_present("mimeType", image.mime_type)
    |> put_if_present("bufferView", image.buffer_view)
    |> put_if_present("name", image.name)
    |> put_if_present("extensions", image.extensions)
    |> put_if_present("extras", image.extras)
  end

  # Helper function
  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)
end
