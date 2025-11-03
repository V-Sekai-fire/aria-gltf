# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.BufferView do
  @moduledoc """
  Mock implementation of AriaGltf.BufferView for compilation.

  This module represents glTF buffer view definitions.
  Currently mocked with basic functionality to enable compilation.
  """

  @type t :: %__MODULE__{
          buffer: non_neg_integer(),
          byte_offset: non_neg_integer(),
          byte_length: non_neg_integer(),
          byte_stride: non_neg_integer() | nil,
          target: non_neg_integer() | nil,
          name: String.t() | nil,
          extensions: map() | nil,
          extras: any() | nil
        }

  defstruct [
    :buffer,
    :byte_offset,
    :byte_length,
    :byte_stride,
    :target,
    :name,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new buffer view with buffer, byte_length, and options.
  """
  @spec new(non_neg_integer(), non_neg_integer(), map()) :: t()
  def new(buffer, byte_length, options \\ %{})
      when is_integer(buffer) and is_integer(byte_length) do
    %__MODULE__{
      buffer: buffer,
      byte_length: byte_length,
      byte_offset: Map.get(options, :byte_offset, 0),
      byte_stride: Map.get(options, :byte_stride),
      target: Map.get(options, :target),
      name: Map.get(options, :name)
    }
  end

  @doc """
  Create a new buffer view from JSON data.
  """
  @spec from_json(map()) :: t()
  def from_json(json) when is_map(json) do
    %__MODULE__{
      buffer: Map.get(json, "buffer"),
      byte_offset: Map.get(json, "byteOffset", 0),
      byte_length: Map.get(json, "byteLength"),
      byte_stride: Map.get(json, "byteStride"),
      target: Map.get(json, "target"),
      name: Map.get(json, "name")
    }
  end

  @doc """
  Convert buffer view to JSON representation.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = buffer_view) do
    %{}
    |> maybe_put("buffer", buffer_view.buffer)
    |> maybe_put("byteOffset", buffer_view.byte_offset, 0)
    |> maybe_put("byteLength", buffer_view.byte_length)
    |> maybe_put("byteStride", buffer_view.byte_stride)
    |> maybe_put("target", buffer_view.target)
    |> maybe_put("name", buffer_view.name)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
  defp maybe_put(map, _key, value, default) when value == default, do: map
  defp maybe_put(map, key, value, _default), do: Map.put(map, key, value)
end
