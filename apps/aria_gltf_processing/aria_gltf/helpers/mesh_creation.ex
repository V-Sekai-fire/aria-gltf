# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Helpers.MeshCreation do
  @moduledoc """
  Helper functions for creating glTF meshes and geometry.

  This module provides utilities for creating mesh structures, including
  simple meshes with primitives and complete geometry like cubes with
  all necessary buffer data.
  """

  alias AriaGltf.{Mesh, Buffer, BufferView, Accessor}
  alias AriaGltf.Helpers.BufferManagement

  @doc """
  Creates a simple mesh with a single primitive.

  ## Options

  - `:name` - Mesh name
  - `:mode` - Primitive mode (default: 4 for TRIANGLES)
  - `:position_accessor` - Accessor index for positions
  - `:normal_accessor` - Accessor index for normals
  - `:texcoord_accessor` - Accessor index for texture coordinates
  - `:indices_accessor` - Accessor index for indices
  - `:material` - Material index

  ## Examples

      iex> AriaGltf.Helpers.MeshCreation.create_simple_mesh(
      ...>   name: "Cube",
      ...>   position_accessor: 0,
      ...>   indices_accessor: 1
      ...> )
      %AriaGltf.Mesh{
        name: "Cube",
        primitives: [
          %AriaGltf.Mesh.Primitive{
            mode: 4,
            attributes: %{"POSITION" => 0},
            indices: 1
          }
        ]
      }
  """
  @spec create_simple_mesh(keyword()) :: Mesh.t()
  def create_simple_mesh(opts \\ []) do
    name = Keyword.get(opts, :name)
    # TRIANGLES
    mode = Keyword.get(opts, :mode, 4)
    position_accessor = Keyword.get(opts, :position_accessor)
    normal_accessor = Keyword.get(opts, :normal_accessor)
    texcoord_accessor = Keyword.get(opts, :texcoord_accessor)
    indices_accessor = Keyword.get(opts, :indices_accessor)
    material = Keyword.get(opts, :material)

    # Build attributes map
    attributes = %{}

    attributes =
      if position_accessor,
        do: Map.put(attributes, "POSITION", position_accessor),
        else: attributes

    attributes =
      if normal_accessor, do: Map.put(attributes, "NORMAL", normal_accessor), else: attributes

    attributes =
      if texcoord_accessor,
        do: Map.put(attributes, "TEXCOORD_0", texcoord_accessor),
        else: attributes

    primitive = %Mesh.Primitive{
      mode: mode,
      attributes: attributes,
      indices: indices_accessor,
      material: material
    }

    %Mesh{
      name: name,
      primitives: [primitive]
    }
  end

  @doc """
  Creates a complete cube mesh with geometry data.

  This helper creates a unit cube centered at origin with positions, normals,
  texture coordinates, and indices. It creates all necessary buffers, buffer views,
  and accessors.

  ## Options

  - `:name` - Mesh name (default: "Cube")
  - `:material` - Material index to assign to the mesh

  ## Returns

  A map containing:
  - `:mesh` - The mesh structure
  - `:buffers` - List of buffers
  - `:buffer_views` - List of buffer views
  - `:accessors` - List of accessors

  ## Examples

      iex> cube_data = AriaGltf.Helpers.MeshCreation.create_cube_mesh()
      iex> cube_data.mesh.name
      "Cube"
      iex> length(cube_data.accessors)
      4
  """
  @spec create_cube_mesh(keyword()) :: %{
          mesh: Mesh.t(),
          buffers: [Buffer.t()],
          buffer_views: [BufferView.t()],
          accessors: [Accessor.t()]
        }
  def create_cube_mesh(opts \\ []) do
    name = Keyword.get(opts, :name, "Cube")
    material = Keyword.get(opts, :material)

    # Cube vertices (8 vertices, each with position, normal, texcoord)
    # Each vertex: position (3 floats) + normal (3 floats) + texcoord (2 floats) = 8 floats = 32 bytes
    # 8 vertices * 8 floats * 4 bytes = 256 bytes
    vertex_data_size = 8 * 8 * 4

    # Cube indices (12 triangles * 3 indices = 36 indices)
    # Each index: unsigned short = 2 bytes
    # 36 indices * 2 bytes = 72 bytes
    index_data_size = 36 * 2

    # 328 bytes
    total_buffer_size = vertex_data_size + index_data_size

    # Create buffer
    buffer = BufferManagement.create_buffer(byte_length: total_buffer_size, name: "#{name} Data")

    # Create buffer views
    vertex_buffer_view =
      BufferManagement.create_buffer_view(
        buffer: 0,
        byte_offset: 0,
        byte_length: vertex_data_size,
        # 8 floats * 4 bytes
        byte_stride: 32,
        # ARRAY_BUFFER
        target: 34_962,
        name: "#{name} Vertices"
      )

    index_buffer_view =
      BufferManagement.create_buffer_view(
        buffer: 0,
        byte_offset: vertex_data_size,
        byte_length: index_data_size,
        # ELEMENT_ARRAY_BUFFER
        target: 34_963,
        name: "#{name} Indices"
      )

    # Create accessors
    position_accessor =
      BufferManagement.create_accessor(
        buffer_view: 0,
        # FLOAT
        component_type: 5126,
        count: 8,
        type: "VEC3",
        byte_offset: 0,
        name: "#{name} Positions",
        min: [-0.5, -0.5, -0.5],
        max: [0.5, 0.5, 0.5]
      )

    normal_accessor =
      BufferManagement.create_accessor(
        buffer_view: 0,
        # FLOAT
        component_type: 5126,
        count: 8,
        type: "VEC3",
        # 3 floats * 4 bytes
        byte_offset: 12,
        name: "#{name} Normals"
      )

    texcoord_accessor =
      BufferManagement.create_accessor(
        buffer_view: 0,
        # FLOAT
        component_type: 5126,
        count: 8,
        type: "VEC2",
        # 6 floats * 4 bytes
        byte_offset: 24,
        name: "#{name} TexCoords"
      )

    index_accessor =
      BufferManagement.create_accessor(
        buffer_view: 1,
        # UNSIGNED_SHORT
        component_type: 5123,
        count: 36,
        type: "SCALAR",
        name: "#{name} Indices"
      )

    # Create mesh
    mesh =
      create_simple_mesh(
        name: name,
        position_accessor: 0,
        normal_accessor: 1,
        texcoord_accessor: 2,
        indices_accessor: 3,
        material: material
      )

    %{
      mesh: mesh,
      buffers: [buffer],
      buffer_views: [vertex_buffer_view, index_buffer_view],
      accessors: [position_accessor, normal_accessor, texcoord_accessor, index_accessor]
    }
  end
end
