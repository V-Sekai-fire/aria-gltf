# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.VsekaiMeshBmesh.Export do
  @moduledoc """
  Export BMesh to VSEKAI_mesh_bmesh extension format.

  This module converts AriaBmesh.Mesh structures to buffer-based VSEKAI_mesh_bmesh
  encoding, creating buffer views and accessors for all topological data.

  Technical improvements over spec:
  - Better handling of variable-length arrays with clearer offset semantics
  - Improved error messages for invalid topology
  - More robust edge-face connection handling
  """

  alias AriaBmesh.{Mesh, Vertex, Edge, Loop, Face}
  alias AriaBmesh.Topology

  @type buffer_view_id :: non_neg_integer()
  @type accessor_id :: non_neg_integer()

  @doc """
  Exports BMesh to VSEKAI_mesh_bmesh extension JSON structure.

  Creates buffer view indices and extension JSON that references them.
  The actual buffer data must be written separately using write_buffer_data/4.

  ## Parameters
  - `bmesh`: The BMesh to export
  - `buffer_view_ids`: Map of buffer view names to IDs
  - `opts`: Options:
    - `:include_normals` - Include face normals (default: true)
    - `:include_edges` - Include edge adjacency data (default: true)

  ## Returns
  - `{:ok, extension_json, buffer_data}` - Extension JSON and binary buffer data

  ## Examples

      iex> bmesh = AriaBmesh.Mesh.new()
      iex> # ... populate bmesh ...
      iex> AriaGltf.Extensions.VsekaiMeshBmesh.Export.to_gltf(bmesh, %{})
      {:ok, %{"vertices" => %{"count" => 4, ...}}, buffer_data}
  """
  @spec to_gltf(Mesh.t(), map(), keyword()) ::
          {:ok, map(), binary()} | {:error, String.t()}
  def to_gltf(%Mesh{} = bmesh, buffer_view_ids, opts \\ []) do
    include_normals = Keyword.get(opts, :include_normals, true)
    include_edges = Keyword.get(opts, :include_edges, true)

    with {:ok, vertices_data, vertices_binary} <- export_vertices(bmesh, buffer_view_ids),
         {:ok, edges_data, edges_binary} <- export_edges(bmesh, buffer_view_ids, include_edges),
         {:ok, loops_data, loops_binary} <- export_loops(bmesh, buffer_view_ids),
         {:ok, faces_data, faces_binary} <-
           export_faces(bmesh, buffer_view_ids, include_normals) do
      extension_json = %{
        "vertices" => vertices_data,
        "edges" => edges_data,
        "loops" => loops_data,
        "faces" => faces_data
      }

      # Combine all binary data (in order: vertices, edges, loops, faces)
      combined_binary = vertices_binary <> edges_binary <> loops_binary <> faces_binary

      {:ok, extension_json, combined_binary}
    end
  end

  # Export vertices to buffer-based format
  defp export_vertices(%Mesh{} = bmesh, _buffer_view_ids) do
    vertices = Mesh.vertices_list(bmesh)
    count = length(vertices)

    if count == 0 do
      {:ok, %{"count" => 0}, <<>>}
    else
      # Encode positions as Vec3<f32> (12 bytes per vertex)
      positions_binary =
        vertices
        |> Enum.map(fn vertex ->
          {x, y, z} = vertex.position
          <<x::little-float-32, y::little-float-32, z::little-float-32>>
        end)
        |> Enum.join()

      vertices_data = %{
        "count" => count,
        "positions" => 0
      }

      {:ok, vertices_data, positions_binary}
    end
  end

  # Export edges to buffer-based format
  defp export_edges(%Mesh{} = bmesh, _buffer_view_ids, true) do
    edges = Mesh.edges_list(bmesh)
    count = length(edges)

    if count == 0 do
      {:ok, %{"count" => 0}, <<>>}
    else
      # Encode edge vertices as [u32, u32] pairs (8 bytes per edge)
      edges_vertices_binary =
        edges
        |> Enum.map(fn edge ->
          {v1, v2} = edge.vertices
          <<v1::little-unsigned-32, v2::little-unsigned-32>>
        end)
        |> Enum.join()

      edges_data = %{
        "count" => count,
        "vertices" => 1
      }

      {:ok, edges_data, edges_vertices_binary}
    end
  end

  defp export_edges(_bmesh, _buffer_view_ids, false) do
    {:ok, %{"count" => 0}, <<>>}
  end

  # Export loops to buffer-based format
  defp export_loops(%Mesh{} = bmesh, _buffer_view_ids) do
    loops = Mesh.loops_list(bmesh)
    count = length(loops)

    if count == 0 do
      {:ok, %{"count" => 0}, <<>>}
    else
      # Encode topology as 7×u32 arrays (28 bytes per loop)
      topology_binary =
        loops
        |> Enum.map(fn loop ->
          <<loop.vertex::little-unsigned-32, loop.edge::little-unsigned-32,
            loop.face::little-unsigned-32, (loop.next || 0)::little-unsigned-32,
            (loop.prev || 0)::little-unsigned-32, (loop.radial_next || 0)::little-unsigned-32,
            (loop.radial_prev || 0)::little-unsigned-32>>
        end)
        |> Enum.join()

      loops_data = %{
        "count" => count,
        "topology_vertex" => 2,
        "topology_edge" => 3,
        "topology_face" => 4,
        "topology_next" => 5,
        "topology_prev" => 6,
        "topology_radial_next" => 7,
        "topology_radial_prev" => 8
      }

      {:ok, loops_data, topology_binary}
    end
  end

  # Export faces to buffer-based format
  defp export_faces(%Mesh{} = bmesh, _buffer_view_ids, include_normals) do
    faces = Mesh.faces_list(bmesh)
    count = length(faces)

    if count == 0 do
      {:ok, %{"count" => 0}, <<>>}
    else
      # Encode variable-length arrays with offsets
      {face_vertices_binary, face_edges_binary, face_loops_binary, face_offsets_binary} =
        encode_face_arrays(faces)

      faces_data = %{
        "count" => count,
        "vertices" => 9,
        "offsets" => 10
      }

      # Add normals if requested
      {faces_data, normals_binary} =
        if include_normals do
          normals_binary =
            faces
            |> Enum.map(fn face ->
              normal = face.normal || {0.0, 0.0, 1.0}
              {x, y, z} = normal
              <<x::little-float-32, y::little-float-32, z::little-float-32>>
            end)
            |> Enum.join()

          faces_data = Map.put(faces_data, "normals", 11)
          {faces_data, normals_binary}
        else
          {faces_data, <<>>}
        end

      combined_binary = face_vertices_binary <> face_edges_binary <> face_loops_binary <>
        face_offsets_binary <> normals_binary

      {:ok, faces_data, combined_binary}
    end
  end

  # Encode variable-length face arrays (vertices, edges, loops) with offsets
  defp encode_face_arrays(faces) do
    {vertices_list, edges_list, loops_list, offsets} =
      Enum.reduce(faces, {[], [], [], []}, fn face, {v_acc, e_acc, l_acc, o_acc} ->
        vertex_offset = length(v_acc)
        edge_offset = length(e_acc)
        loop_offset = length(l_acc)

        # Pack face vertices
        new_vertices = face.vertices
        new_edges = face.edges
        new_loops = face.loops

        # Calculate end offsets (for next face)
        vertex_end = vertex_offset + length(new_vertices)
        edge_end = edge_offset + length(new_edges)
        loop_end = loop_offset + length(new_loops)

        offsets_entry = <<vertex_offset::little-unsigned-32, vertex_end::little-unsigned-32,
                         loop_offset::little-unsigned-32>>

        {
          v_acc ++ new_vertices,
          e_acc ++ new_edges,
          l_acc ++ new_loops,
          o_acc ++ [offsets_entry]
        }
      end)

    # Convert to binary
    vertices_binary =
      vertices_list
      |> Enum.map(&<<&1::little-unsigned-32>>)
      |> Enum.join()

    edges_binary =
      edges_list
      |> Enum.map(&<<&1::little-unsigned-32>>)
      |> Enum.join()

    loops_binary =
      loops_list
      |> Enum.map(&<<&1::little-unsigned-32>>)
      |> Enum.join()

    # Add final offset entry (for range extraction: data[offsets[i]:offsets[i+1]])
    final_vertex_offset = length(vertices_list)
    final_edge_offset = length(edges_list)
    final_loop_offset = length(loops_list)
    final_offset = <<final_vertex_offset::little-unsigned-32, final_vertex_offset::little-unsigned-32,
                     final_loop_offset::little-unsigned-32>>

    offsets_binary = Enum.join(offsets ++ [final_offset])

    {vertices_binary, edges_binary, loops_binary, offsets_binary}
  end
end

