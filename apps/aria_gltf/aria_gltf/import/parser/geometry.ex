# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.Parser.Geometry do
  @moduledoc """
  Geometry-related parsing for glTF content.

  This module handles parsing of meshes, primitives, accessors, buffers, and buffer views
  from glTF JSON data.
  """

  alias AriaGltf.{Mesh, Accessor, BufferView, Buffer}

  @doc """
  Parses meshes array from glTF JSON data.

  ## Examples

      iex> meshes_data = [%{"name" => "Cube", "primitives" => [%{"attributes" => %{"POSITION" => 0}}]}]
      iex> AriaGltf.Import.Parser.Geometry.parse_meshes(meshes_data)
      [%AriaGltf.Mesh{name: "Cube", primitives: [%AriaGltf.Mesh.Primitive{attributes: %{"POSITION" => 0}}]}]
  """
  @spec parse_meshes(list() | nil) :: [Mesh.t()]
  def parse_meshes(nil), do: []

  def parse_meshes(meshes_data) when is_list(meshes_data) do
    Enum.map(meshes_data, &parse_mesh/1)
  end

  @spec parse_mesh(map()) :: Mesh.t()
  defp parse_mesh(mesh_data) when is_map(mesh_data) do
    %Mesh{
      name: mesh_data["name"],
      primitives: parse_primitives(mesh_data["primitives"]),
      weights: mesh_data["weights"],
      extensions: mesh_data["extensions"],
      extras: mesh_data["extras"]
    }
  end

  @spec parse_primitives(list() | nil) :: [Mesh.Primitive.t()]
  defp parse_primitives(nil), do: []

  defp parse_primitives(primitives_data) when is_list(primitives_data) do
    Enum.map(primitives_data, &parse_primitive/1)
  end

  @spec parse_primitive(map()) :: Mesh.Primitive.t()
  defp parse_primitive(primitive_data) when is_map(primitive_data) do
    %Mesh.Primitive{
      attributes: primitive_data["attributes"] || %{},
      indices: primitive_data["indices"],
      material: primitive_data["material"],
      # TRIANGLES
      mode: primitive_data["mode"] || 4,
      targets: parse_morph_targets(primitive_data["targets"]),
      extensions: primitive_data["extensions"],
      extras: primitive_data["extras"]
    }
  end

  @spec parse_morph_targets(list() | nil) :: list()
  defp parse_morph_targets(nil), do: []

  defp parse_morph_targets(targets_data) when is_list(targets_data) do
    targets_data
  end

  @doc """
  Parses accessors array from glTF JSON data.

  ## Examples

      iex> accessors_data = [%{"bufferView" => 0, "componentType" => 5126, "count" => 24, "type" => "VEC3"}]
      iex> AriaGltf.Import.Parser.Geometry.parse_accessors(accessors_data)
      [%AriaGltf.Accessor{buffer_view: 0, component_type: 5126, count: 24, type: "VEC3"}]
  """
  @spec parse_accessors(list() | nil) :: [Accessor.t()]
  def parse_accessors(nil), do: []

  def parse_accessors(accessors_data) when is_list(accessors_data) do
    Enum.map(accessors_data, &parse_accessor/1)
  end

  @spec parse_accessor(map()) :: Accessor.t()
  defp parse_accessor(accessor_data) when is_map(accessor_data) do
    %Accessor{
      name: accessor_data["name"],
      buffer_view: accessor_data["bufferView"],
      byte_offset: accessor_data["byteOffset"] || 0,
      component_type: accessor_data["componentType"],
      normalized: accessor_data["normalized"] || false,
      count: accessor_data["count"],
      type: accessor_data["type"],
      max: accessor_data["max"],
      min: accessor_data["min"],
      sparse: parse_sparse(accessor_data["sparse"]),
      extensions: accessor_data["extensions"],
      extras: accessor_data["extras"]
    }
  end

  @spec parse_sparse(map() | nil) :: Accessor.Sparse.t() | nil
  defp parse_sparse(nil), do: nil

  defp parse_sparse(sparse_data) when is_map(sparse_data) do
    %Accessor.Sparse{
      count: sparse_data["count"],
      indices: parse_sparse_indices(sparse_data["indices"]),
      values: parse_sparse_values(sparse_data["values"]),
      extensions: sparse_data["extensions"],
      extras: sparse_data["extras"]
    }
  end

  @spec parse_sparse_indices(map() | nil) :: Accessor.Sparse.Indices.t() | nil
  defp parse_sparse_indices(nil), do: nil

  defp parse_sparse_indices(indices_data) when is_map(indices_data) do
    %Accessor.Sparse.Indices{
      buffer_view: indices_data["bufferView"],
      byte_offset: indices_data["byteOffset"] || 0,
      component_type: indices_data["componentType"],
      extensions: indices_data["extensions"],
      extras: indices_data["extras"]
    }
  end

  @spec parse_sparse_values(map() | nil) :: Accessor.Sparse.Values.t() | nil
  defp parse_sparse_values(nil), do: nil

  defp parse_sparse_values(values_data) when is_map(values_data) do
    %Accessor.Sparse.Values{
      buffer_view: values_data["bufferView"],
      byte_offset: values_data["byteOffset"] || 0,
      extensions: values_data["extensions"],
      extras: values_data["extras"]
    }
  end

  @doc """
  Parses buffer views array from glTF JSON data.

  ## Examples

      iex> buffer_views_data = [%{"buffer" => 0, "byteLength" => 288, "target" => 34962}]
      iex> AriaGltf.Import.Parser.Geometry.parse_buffer_views(buffer_views_data)
      [%AriaGltf.BufferView{buffer: 0, byte_length: 288, target: 34962}]
  """
  @spec parse_buffer_views(list() | nil) :: [BufferView.t()]
  def parse_buffer_views(nil), do: []

  def parse_buffer_views(buffer_views_data) when is_list(buffer_views_data) do
    Enum.map(buffer_views_data, &parse_buffer_view/1)
  end

  @spec parse_buffer_view(map()) :: BufferView.t()
  defp parse_buffer_view(buffer_view_data) when is_map(buffer_view_data) do
    %BufferView{
      name: buffer_view_data["name"],
      buffer: buffer_view_data["buffer"],
      byte_offset: buffer_view_data["byteOffset"] || 0,
      byte_length: buffer_view_data["byteLength"],
      byte_stride: buffer_view_data["byteStride"],
      target: buffer_view_data["target"],
      extensions: buffer_view_data["extensions"],
      extras: buffer_view_data["extras"]
    }
  end

  @doc """
  Parses buffers array from glTF JSON data.

  ## Examples

      iex> buffers_data = [%{"byteLength" => 1024, "uri" => "data.bin"}]
      iex> AriaGltf.Import.Parser.Geometry.parse_buffers(buffers_data)
      [%AriaGltf.Buffer{byte_length: 1024, uri: "data.bin"}]
  """
  @spec parse_buffers(list() | nil) :: [Buffer.t()]
  def parse_buffers(nil), do: []

  def parse_buffers(buffers_data) when is_list(buffers_data) do
    Enum.map(buffers_data, &parse_buffer/1)
  end

  @spec parse_buffer(map()) :: Buffer.t()
  defp parse_buffer(buffer_data) when is_map(buffer_data) do
    %Buffer{
      name: buffer_data["name"],
      uri: buffer_data["uri"],
      byte_length: buffer_data["byteLength"],
      extensions: buffer_data["extensions"],
      extras: buffer_data["extras"]
    }
  end
end
