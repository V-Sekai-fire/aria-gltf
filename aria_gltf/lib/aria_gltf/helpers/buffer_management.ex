# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Helpers.BufferManagement do
  @moduledoc """
  Helper functions for creating and managing glTF buffers, buffer views, and accessors.

  This module provides utilities for setting up the data storage layer of glTF documents,
  including buffer allocation, view creation, and accessor configuration.
  """

  alias AriaGltf.{Buffer, BufferView, Accessor}

  @doc """
  Creates a buffer with specified byte length.

  ## Options

  - `:byte_length` - Buffer size in bytes (required)
  - `:uri` - Buffer URI (external file or data URI)
  - `:name` - Buffer name

  ## Examples

      iex> AriaGltf.Helpers.BufferManagement.create_buffer(byte_length: 1024)
      %AriaGltf.Buffer{byte_length: 1024}

      iex> AriaGltf.Helpers.BufferManagement.create_buffer(
      ...>   byte_length: 2048,
      ...>   uri: "geometry.bin",
      ...>   name: "Mesh Data"
      ...> )
      %AriaGltf.Buffer{
        byte_length: 2048,
        uri: "geometry.bin",
        name: "Mesh Data"
      }
  """
  @spec create_buffer(keyword()) :: Buffer.t()
  def create_buffer(opts \\ []) do
    byte_length = Keyword.fetch!(opts, :byte_length)
    uri = Keyword.get(opts, :uri)
    name = Keyword.get(opts, :name)

    %Buffer{
      byte_length: byte_length,
      uri: uri,
      name: name
    }
  end

  @doc """
  Creates a buffer view with specified parameters.

  ## Options

  - `:buffer` - Buffer index (required)
  - `:byte_offset` - Byte offset (default: 0)
  - `:byte_length` - Byte length (required)
  - `:byte_stride` - Byte stride for interleaved data
  - `:target` - Buffer view target (34962 for ARRAY_BUFFER, 34963 for ELEMENT_ARRAY_BUFFER)
  - `:name` - Buffer view name

  ## Examples

      iex> AriaGltf.Helpers.BufferManagement.create_buffer_view(buffer: 0, byte_length: 512)
      %AriaGltf.BufferView{
        buffer: 0,
        byte_offset: 0,
        byte_length: 512
      }

      iex> AriaGltf.Helpers.BufferManagement.create_buffer_view(
      ...>   buffer: 0,
      ...>   byte_offset: 100,
      ...>   byte_length: 300,
      ...>   target: 34962,
      ...>   name: "Positions"
      ...> )
      %AriaGltf.BufferView{
        buffer: 0,
        byte_offset: 100,
        byte_length: 300,
        target: 34962,
        name: "Positions"
      }
  """
  @spec create_buffer_view(keyword()) :: BufferView.t()
  def create_buffer_view(opts \\ []) do
    buffer = Keyword.fetch!(opts, :buffer)
    byte_offset = Keyword.get(opts, :byte_offset, 0)
    byte_length = Keyword.fetch!(opts, :byte_length)
    byte_stride = Keyword.get(opts, :byte_stride)
    target = Keyword.get(opts, :target)
    name = Keyword.get(opts, :name)

    %BufferView{
      buffer: buffer,
      byte_offset: byte_offset,
      byte_length: byte_length,
      byte_stride: byte_stride,
      target: target,
      name: name
    }
  end

  @doc """
  Creates an accessor with specified parameters.

  ## Options

  - `:buffer_view` - Buffer view index (required)
  - `:component_type` - Component type (5126 for FLOAT, 5123 for UNSIGNED_SHORT, etc.)
  - `:count` - Number of elements (required)
  - `:type` - Data type ("SCALAR", "VEC2", "VEC3", "VEC4", "MAT2", "MAT3", "MAT4")
  - `:byte_offset` - Byte offset within buffer view (default: 0)
  - `:normalized` - Whether data is normalized
  - `:max` - Maximum values
  - `:min` - Minimum values
  - `:name` - Accessor name

  ## Examples

      iex> AriaGltf.Helpers.BufferManagement.create_accessor(
      ...>   buffer_view: 0,
      ...>   component_type: 5126,
      ...>   count: 8,
      ...>   type: "VEC3"
      ...> )
      %AriaGltf.Accessor{
        buffer_view: 0,
        component_type: 5126,
        count: 8,
        type: "VEC3",
        byte_offset: 0
      }

      iex> AriaGltf.Helpers.BufferManagement.create_accessor(
      ...>   buffer_view: 1,
      ...>   component_type: 5123,
      ...>   count: 36,
      ...>   type: "SCALAR",
      ...>   name: "Cube Indices"
      ...> )
      %AriaGltf.Accessor{
        buffer_view: 1,
        component_type: 5123,
        count: 36,
        type: "SCALAR",
        byte_offset: 0,
        name: "Cube Indices"
      }
  """
  @spec create_accessor(keyword()) :: Accessor.t()
  def create_accessor(opts \\ []) do
    buffer_view = Keyword.fetch!(opts, :buffer_view)
    component_type = Keyword.fetch!(opts, :component_type)
    count = Keyword.fetch!(opts, :count)
    type = Keyword.fetch!(opts, :type)
    byte_offset = Keyword.get(opts, :byte_offset, 0)
    normalized = Keyword.get(opts, :normalized)
    max = Keyword.get(opts, :max)
    min = Keyword.get(opts, :min)
    name = Keyword.get(opts, :name)

    %Accessor{
      buffer_view: buffer_view,
      component_type: component_type,
      count: count,
      type: type,
      byte_offset: byte_offset,
      normalized: normalized,
      max: max,
      min: min,
      name: name
    }
  end
end
