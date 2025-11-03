# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaBmesh.Topology do
  @moduledoc """
  BMesh topological navigation functions.

  Provides functions for traversing BMesh topology:
  - Radial loops around edges (non-manifold support)
  - Face boundaries via loop navigation
  - Vertex-edge connections
  - Edge-face connections
  """

  alias AriaBmesh.{Mesh, Vertex, Edge, Loop, Face}

  @doc """
  Gets all loops around an edge (radial navigation).

  Traverses the radial_next/radial_prev pointers to collect
  all loops sharing an edge (supports non-manifold geometry).

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> # ... create mesh with loops ...
      iex> AriaBmesh.Topology.edge_loops(mesh, edge_id)
      [loop1, loop2, loop3]
  """
  @spec edge_loops(Mesh.t(), non_neg_integer()) :: [Loop.t()]
  def edge_loops(%Mesh{} = mesh, edge_id) do
    # Find all loops that reference this edge
    mesh.loops
    |> Map.values()
    |> Enum.filter(fn loop -> loop.edge == edge_id end)
  end

  @doc """
  Gets all faces sharing an edge (non-manifold support).

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> edge = AriaBmesh.Mesh.get_edge(mesh, edge_id)
      iex> AriaBmesh.Topology.edge_faces(mesh, edge)
      [face1, face2, face3]  # Can be multiple for non-manifold
  """
  @spec edge_faces(Mesh.t(), Edge.t()) :: [Face.t()]
  def edge_faces(%Mesh{} = mesh, %Edge{} = edge) do
    edge.faces
    |> Enum.map(fn face_id -> Mesh.get_face(mesh, face_id) end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  @doc """
  Gets all faces containing a vertex.

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> AriaBmesh.Topology.vertex_faces(mesh, vertex_id)
      [face1, face2]
  """
  @spec vertex_faces(Mesh.t(), non_neg_integer()) :: [Face.t()]
  def vertex_faces(%Mesh{} = mesh, vertex_id) do
    mesh.faces
    |> Map.values()
    |> Enum.filter(fn face -> vertex_id in face.vertices end)
  end

  @doc """
  Gets all edges connected to a vertex.

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> vertex = AriaBmesh.Mesh.get_vertex(mesh, vertex_id)
      iex> AriaBmesh.Topology.vertex_edges(mesh, vertex)
      [edge1, edge2, edge3]
  """
  @spec vertex_edges(Mesh.t(), Vertex.t()) :: [Edge.t()]
  def vertex_edges(%Mesh{} = mesh, %Vertex{} = vertex) do
    vertex.edges
    |> Enum.map(fn edge_id -> Mesh.get_edge(mesh, edge_id) end)
    |> Enum.filter(&(!is_nil(&1)))
  end

  @doc """
  Gets all loops in a face boundary (in order).

  Traverses the face's loops using next/prev pointers.

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> face = AriaBmesh.Mesh.get_face(mesh, face_id)
      iex> AriaBmesh.Topology.face_loops(mesh, face)
      [loop1, loop2, loop3, ...]  # In boundary order
  """
  @spec face_loops(Mesh.t(), Face.t()) :: [Loop.t()]
  def face_loops(%Mesh{} = mesh, %Face{} = face) do
    case face.loops do
      [] ->
        []

      [first_loop_id | _] ->
        traverse_loop_ring(mesh, first_loop_id, [])
    end
  end

  @doc """
  Gets the vertices of a face (in boundary order via loops).

  Uses loop navigation to get vertices in the correct order.

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> face = AriaBmesh.Mesh.get_face(mesh, face_id)
      iex> AriaBmesh.Topology.face_vertices_ordered(mesh, face)
      [vertex1, vertex2, vertex3, ...]  # In boundary order
  """
  @spec face_vertices_ordered(Mesh.t(), Face.t()) :: [non_neg_integer()]
  def face_vertices_ordered(%Mesh{} = mesh, %Face{} = face) do
    face_loops(mesh, face)
    |> Enum.map(fn loop -> loop.vertex end)
  end

  @doc """
  Checks if an edge is manifold (connects exactly two faces).

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> edge = AriaBmesh.Mesh.get_edge(mesh, edge_id)
      iex> AriaBmesh.Topology.edge_manifold?(mesh, edge)
      true  # or false for non-manifold
  """
  @spec edge_manifold?(Mesh.t(), Edge.t()) :: boolean()
  def edge_manifold?(%Mesh{} = _mesh, %Edge{} = edge) do
    length(edge.faces) == 2
  end

  @doc """
  Checks if an edge is boundary (connects exactly one face).

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> edge = AriaBmesh.Mesh.get_edge(mesh, edge_id)
      iex> AriaBmesh.Topology.edge_boundary?(mesh, edge)
      true  # or false
  """
  @spec edge_boundary?(Mesh.t(), Edge.t()) :: boolean()
  def edge_boundary?(%Mesh{} = _mesh, %Edge{} = edge) do
    length(edge.faces) == 1
  end

  @doc """
  Checks if an edge is non-manifold (connects more than two faces).

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> edge = AriaBmesh.Mesh.get_edge(mesh, edge_id)
      iex> AriaBmesh.Topology.edge_non_manifold?(mesh, edge)
      true  # or false
  """
  @spec edge_non_manifold?(Mesh.t(), Edge.t()) :: boolean()
  def edge_non_manifold?(%Mesh{} = _mesh, %Edge{} = edge) do
    length(edge.faces) > 2
  end

  # Private helper: Traverse loop ring using next pointers
  defp traverse_loop_ring(%Mesh{} = mesh, loop_id, visited) do
    if loop_id in visited do
      Enum.reverse(visited)
    else
      case Mesh.get_loop(mesh, loop_id) do
        nil ->
          Enum.reverse(visited)

        loop ->
          next_id = loop.next
          traverse_loop_ring(mesh, next_id, [loop | visited])
      end
    end
  end
end

