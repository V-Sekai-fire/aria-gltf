# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.VsekaiMeshBmesh.Import do
  @moduledoc """
  Import VSEKAI_mesh_bmesh extension data into BMesh format.

  This module parses buffer-based BMesh data from VSEKAI_mesh_bmesh extension
  and converts it to AriaBmesh.Mesh structures.
  """

  alias AriaBmesh.Mesh
  alias AriaGltf.{Document, Buffer}

  @doc """
  Imports VSEKAI_mesh_bmesh extension data from a glTF primitive into BMesh.

  ## Parameters
  - `document`: The glTF document containing buffers and buffer views
  - `primitive`: The primitive with VSEKAI_mesh_bmesh extension
  - `ext_bmesh`: The VSEKAI_mesh_bmesh extension JSON data

  ## Returns
  - `{:ok, bmesh}` - Successfully imported BMesh
  - `{:error, reason}` - Error during import

  ## Examples

      iex> ext_bmesh = %{"vertices" => %{"count" => 4, "positions" => 0}}
      iex> AriaGltf.Extensions.VsekaiMeshBmesh.Import.from_gltf(document, primitive, ext_bmesh)
      {:ok, %AriaBmesh.Mesh{}}
  """
  @spec from_gltf(Document.t(), AriaGltf.Mesh.Primitive.t(), map()) ::
          {:ok, Mesh.t()} | {:error, String.t()}
  def from_gltf(%Document{} = document, _primitive, ext_bmesh) when is_map(ext_bmesh) do
    bmesh = Mesh.new()

    with {:ok, bmesh} <- import_vertices(bmesh, document, ext_bmesh),
         {:ok, bmesh} <- import_edges(bmesh, document, ext_bmesh),
         {:ok, bmesh} <- import_loops(bmesh, document, ext_bmesh),
         {:ok, bmesh} <- import_faces(bmesh, document, ext_bmesh) do
      {:ok, bmesh}
    end
  end

  def from_gltf(_, _, _), do: {:error, "Invalid VSEKAI_mesh_bmesh extension data"}

  # Import vertices from buffer views
  defp import_vertices(%Mesh{} = bmesh, %Document{} = document, ext_bmesh) do
    vertices_data = Map.get(ext_bmesh, "vertices", %{})
    count = Map.get(vertices_data, "count", 0)

    if count == 0 do
      {:ok, bmesh}
    else
      positions_bv = Map.get(vertices_data, "positions")

      if is_nil(positions_bv) do
        {:error, "VSEKAI_mesh_bmesh vertices.positions buffer view is required"}
      else
        with {:ok, positions} <- read_vec3_buffer_view(document, positions_bv, count),
             {:ok, bmesh} <- create_vertices(bmesh, positions, vertices_data, document) do
          {:ok, bmesh}
        end
      end
    end
  end

  # Create vertices from positions
  defp create_vertices(%Mesh{} = bmesh, positions, vertices_data, document) do
    attributes_data = Map.get(vertices_data, "attributes", %{})
    normals_bv = Map.get(attributes_data, "NORMAL")
    tangents_bv = Map.get(attributes_data, "TANGENT")
    crease_bv = Map.get(attributes_data, "CREASE")

    {bmesh, _} =
      Enum.reduce(positions, {bmesh, 0}, fn {x, y, z}, {mesh, index} ->
        opts = []
        opts = if normals_bv, do: add_normal_attribute(opts, document, normals_bv, index), else: opts
        opts = if tangents_bv, do: add_tangent_attribute(opts, document, tangents_bv, index), else: opts
        opts = if crease_bv, do: add_crease_attribute(opts, document, crease_bv, index), else: opts

        {mesh, vertex_id} = Mesh.add_vertex(mesh, {x, y, z}, opts)
        {mesh, vertex_id + 1}
      end)

    {:ok, bmesh}
  end

  # Import edges from buffer views
  defp import_edges(%Mesh{} = bmesh, %Document{} = document, ext_bmesh) do
    edges_data = Map.get(ext_bmesh, "edges", %{})
    count = Map.get(edges_data, "count", 0)

    if count == 0 do
      {:ok, bmesh}
    else
      vertices_bv = Map.get(edges_data, "vertices")

      if is_nil(vertices_bv) do
        {:error, "VSEKAI_mesh_bmesh edges.vertices buffer view is required"}
      else
        with {:ok, edge_vertices} <- read_uint32_pair_buffer_view(document, vertices_bv, count),
             {:ok, bmesh} <- create_edges(bmesh, edge_vertices, edges_data, document) do
          {:ok, bmesh}
        end
      end
    end
  end

  # Create edges from vertex pairs
  defp create_edges(%Mesh{} = bmesh, edge_vertices, edges_data, document) do
    attributes_data = Map.get(edges_data, "attributes", %{})
    crease_bv = Map.get(attributes_data, "CREASE")

    {bmesh, _} =
      Enum.reduce(edge_vertices, {bmesh, 0}, fn {v1, v2}, {mesh, index} ->
        opts = []
        opts = if crease_bv, do: add_edge_crease_attribute(opts, document, crease_bv, index), else: opts

        {mesh, _edge_id} = Mesh.add_edge(mesh, {v1, v2}, opts)
        {mesh, index + 1}
      end)

    {:ok, bmesh}
  end

  # Import loops from buffer views
  defp import_loops(%Mesh{} = bmesh, %Document{} = document, ext_bmesh) do
    loops_data = Map.get(ext_bmesh, "loops", %{})
    count = Map.get(loops_data, "count", 0)

    if count == 0 do
      {:ok, bmesh}
    else
      required_fields = [
        "topology_vertex",
        "topology_edge",
        "topology_face",
        "topology_next",
        "topology_prev",
        "topology_radial_next",
        "topology_radial_prev"
      ]

      with :ok <- validate_required_loop_fields(loops_data, required_fields),
           {:ok, topology} <- read_loop_topology(document, loops_data, count),
           {:ok, bmesh} <- create_loops(bmesh, topology, loops_data, document) do
        {:ok, bmesh}
      end
    end
  end

  # Validate required loop topology fields
  defp validate_required_loop_fields(loops_data, required_fields) do
    missing =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(loops_data, field)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required loop fields: #{inspect(missing)}"}
    end
  end

  # Read loop topology from buffer views
  defp read_loop_topology(document, loops_data, count) do
    with {:ok, vertex} <- read_uint32_buffer_view(document, Map.get(loops_data, "topology_vertex"), count),
         {:ok, edge} <- read_uint32_buffer_view(document, Map.get(loops_data, "topology_edge"), count),
         {:ok, face} <- read_uint32_buffer_view(document, Map.get(loops_data, "topology_face"), count),
         {:ok, next} <- read_uint32_buffer_view(document, Map.get(loops_data, "topology_next"), count),
         {:ok, prev} <- read_uint32_buffer_view(document, Map.get(loops_data, "topology_prev"), count),
         {:ok, radial_next} <-
           read_uint32_buffer_view(document, Map.get(loops_data, "topology_radial_next"), count),
         {:ok, radial_prev} <-
           read_uint32_buffer_view(document, Map.get(loops_data, "topology_radial_prev"), count) do
      {:ok,
       %{
         vertex: vertex,
         edge: edge,
         face: face,
         next: next,
         prev: prev,
         radial_next: radial_next,
         radial_prev: radial_prev
       }}
    end
  end

  # Create loops from topology
  defp create_loops(%Mesh{} = bmesh, topology, loops_data, document) do
    attributes_data = Map.get(loops_data, "attributes", %{})
    texcoord_bv = Map.get(attributes_data, "TEXCOORD_0")
    color_bv = Map.get(attributes_data, "COLOR_0")

    count = length(topology.vertex)

    {bmesh, _} =
      Enum.reduce(0..(count - 1), {bmesh, 0}, fn i, {mesh, _} ->
        vertex = Enum.at(topology.vertex, i)
        edge = Enum.at(topology.edge, i)
        face = Enum.at(topology.face, i)
        next = Enum.at(topology.next, i)
        prev = Enum.at(topology.prev, i)
        radial_next = Enum.at(topology.radial_next, i)
        radial_prev = Enum.at(topology.radial_prev, i)

        opts = [
          next: next,
          prev: prev,
          radial_next: radial_next,
          radial_prev: radial_prev,
          attributes: %{}
        ]

        opts =
          if texcoord_bv do
            add_loop_texcoord_attribute(opts, document, texcoord_bv, i)
          else
            opts
          end

        opts =
          if color_bv do
            add_loop_color_attribute(opts, document, color_bv, i)
          else
            opts
          end

        {mesh, _loop_id} = Mesh.add_loop(mesh, vertex, edge, face, opts)
        {mesh, i + 1}
      end)

    {:ok, bmesh}
  end

  # Import faces from buffer views
  defp import_faces(%Mesh{} = bmesh, %Document{} = document, ext_bmesh) do
    faces_data = Map.get(ext_bmesh, "faces", %{})
    count = Map.get(faces_data, "count", 0)

    if count == 0 do
      {:ok, bmesh}
    else
      vertices_bv = Map.get(faces_data, "vertices")
      offsets_bv = Map.get(faces_data, "offsets")

      if is_nil(vertices_bv) or is_nil(offsets_bv) do
        {:error, "VSEKAI_mesh_bmesh faces.vertices and faces.offsets buffer views are required"}
      else
        with {:ok, face_vertices} <- read_uint32_buffer_view(document, vertices_bv, :variable),
             {:ok, face_offsets} <- read_face_offsets(document, offsets_bv, count + 1),
             {:ok, normals} <-
               read_face_normals(document, faces_data, count),
             {:ok, bmesh} <-
               create_faces(bmesh, face_vertices, face_offsets, normals, faces_data, document) do
          {:ok, bmesh}
        end
      end
    end
  end

  # Create faces from variable-length vertex arrays
  defp create_faces(%Mesh{} = bmesh, face_vertices, offsets, normals, faces_data, document) do
    attributes_data = Map.get(faces_data, "attributes", %{})
    holes_bv = Map.get(attributes_data, "HOLES")

    count = length(offsets) - 1

    {bmesh, _} =
      Enum.reduce(0..(count - 1), {bmesh, 0}, fn i, {mesh, _} ->
        vertex_start = Enum.at(offsets, i)
        vertex_end = Enum.at(offsets, i + 1)
        vertex_count = vertex_end - vertex_start
        vertices = Enum.slice(face_vertices, vertex_start, vertex_count)

        opts = []

        # Add normal if present
        opts =
          if normals do
            normal = Enum.at(normals, i)
            Keyword.put(opts, :normal, normal)
          else
            opts
          end

        # Add holes attribute if present
        opts =
          if holes_bv do
            add_face_holes_attribute(opts, document, holes_bv, i)
          else
            opts
          end

        {mesh, _face_id} = Mesh.add_face(mesh, vertices, opts)
        {mesh, i + 1}
      end)

    {:ok, bmesh}
  end

  # Helper functions for reading buffer views

  # Read Vec3<f32> buffer view (12 bytes per element)
  defp read_vec3_buffer_view(document, bv_index, count) when is_integer(count) do
    case read_buffer_view_data(document, bv_index) do
      {:ok, data} ->
        positions =
          0..(count - 1)
          |> Enum.map(fn i ->
            offset = i * 12
            <<x::little-float-32, y::little-float-32, z::little-float-32>> = binary_part(data, offset, 12)
            {x, y, z}
          end)

        {:ok, positions}

      error ->
        error
    end
  end

  # Read u32 buffer view (4 bytes per element)
  defp read_uint32_buffer_view(document, bv_index, count) when is_integer(count) do
    case read_buffer_view_data(document, bv_index) do
      {:ok, data} ->
        values =
          0..(count - 1)
          |> Enum.map(fn i ->
            offset = i * 4
            <<value::little-unsigned-32>> = binary_part(data, offset, 4)
            value
          end)

        {:ok, values}

      error ->
        error
    end
  end

  # Read u32 buffer view (variable length, read all)
  defp read_uint32_buffer_view(document, bv_index, :variable) do
    case read_buffer_view_data(document, bv_index) do
      {:ok, data} ->
        count = div(byte_size(data), 4)
        values =
          0..(count - 1)
          |> Enum.map(fn i ->
            offset = i * 4
            <<value::little-unsigned-32>> = binary_part(data, offset, 4)
            value
          end)

        {:ok, values}

      error ->
        error
    end
  end

  # Read u32 pair buffer view (8 bytes per element, [u32, u32])
  defp read_uint32_pair_buffer_view(document, bv_index, count) do
    case read_buffer_view_data(document, bv_index) do
      {:ok, data} ->
        pairs =
          0..(count - 1)
          |> Enum.map(fn i ->
            offset = i * 8
            <<v1::little-unsigned-32, v2::little-unsigned-32>> = binary_part(data, offset, 8)
            {v1, v2}
          end)

        {:ok, pairs}

      error ->
        error
    end
  end

  # Read face offsets ([u32; 3] per element: [vertex_start, edge_start, loop_start])
  # The offsets array has count+1 elements to allow range extraction: data[offsets[i]:offsets[i+1]]
  defp read_face_offsets(document, bv_index, count) when is_integer(count) do
    case read_buffer_view_data(document, bv_index) do
      {:ok, data} ->
        # Each offset tuple is [u32; 3] (12 bytes): [vertex_start, edge_start, loop_start]
        # We need count+1 elements for proper range extraction
        offsets =
          0..(count - 1)
          |> Enum.map(fn i ->
            offset = i * 12
            <<vertex_start::little-unsigned-32, _edge_start::little-unsigned-32,
              _loop_start::little-unsigned-32>> = binary_part(data, offset, 12)
            vertex_start
          end)

        {:ok, offsets}

      error ->
        error
    end
  end

  # Read face normals (Vec3<f32> per face)
  defp read_face_normals(document, faces_data, count) do
    normals_bv = Map.get(faces_data, "normals")

    if is_nil(normals_bv) do
      {:ok, nil}
    else
      read_vec3_buffer_view(document, normals_bv, count)
    end
  end

  # Read buffer view data from document
  defp read_buffer_view_data(%Document{} = document, bv_index) when is_integer(bv_index) do
    buffer_views = document.buffer_views || []
    buffers = document.buffers || []

    case Enum.at(buffer_views, bv_index) do
      nil ->
        {:error, "Invalid buffer view index: #{bv_index}"}

      buffer_view ->
        buffer_index = buffer_view.buffer

        case Enum.at(buffers, buffer_index) do
          nil ->
            {:error, "Invalid buffer index: #{buffer_index}"}

          %Buffer{data: nil} ->
            {:error, "Buffer #{buffer_index} has no data"}

          %Buffer{data: buffer_data} ->
            offset = buffer_view.byte_offset || 0
            length = buffer_view.byte_length

            if byte_size(buffer_data) >= offset + length do
              <<_::binary-size(offset), data::binary-size(length), _::binary>> = buffer_data
              {:ok, data}
            else
              {:error, "Buffer view extends beyond buffer data"}
            end
        end
    end
  end

  # Attribute helper functions (stubs for now)
  defp add_normal_attribute(opts, _document, _bv_index, _index), do: opts
  defp add_tangent_attribute(opts, _document, _bv_index, _index), do: opts
  defp add_crease_attribute(opts, _document, _bv_index, _index), do: opts
  defp add_edge_crease_attribute(opts, _document, _bv_index, _index), do: opts
  defp add_loop_texcoord_attribute(opts, _document, _bv_index, _index), do: opts
  defp add_loop_color_attribute(opts, _document, _bv_index, _index), do: opts
  defp add_face_holes_attribute(opts, _document, _bv_index, _index), do: opts
end

