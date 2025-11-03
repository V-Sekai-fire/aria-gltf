# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaBmesh.Mesh do
  @moduledoc """
  BMesh container and operations.

  A BMesh is a complete topological representation with:
  - Vertices (position data)
  - Edges (topology connections)
  - Loops (face corners with navigation)
  - Faces (polygons, including n-gons)

  Supports non-manifold geometry where edges can connect multiple faces.
  """

  alias AriaBmesh.{Vertex, Edge, Loop, Face}

  @type t :: %__MODULE__{
          vertices: %{non_neg_integer() => Vertex.t()},
          edges: %{non_neg_integer() => Edge.t()},
          loops: %{non_neg_integer() => Loop.t()},
          faces: %{non_neg_integer() => Face.t()},
          next_vertex_id: non_neg_integer(),
          next_edge_id: non_neg_integer(),
          next_loop_id: non_neg_integer(),
          next_face_id: non_neg_integer()
        }

  @enforce_keys []
  defstruct [
    vertices: %{},
    edges: %{},
    loops: %{},
    faces: %{},
    next_vertex_id: 0,
    next_edge_id: 0,
    next_loop_id: 0,
    next_face_id: 0
  ]

  @doc """
  Creates a new empty BMesh.

  ## Examples

      iex> AriaBmesh.Mesh.new()
      %AriaBmesh.Mesh{vertices: %{}, edges: %{}, loops: %{}, faces: %{}}
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Adds a vertex to the mesh.

  Returns `{mesh, vertex_id}` where `vertex_id` is the newly assigned ID.

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> {mesh, id} = AriaBmesh.Mesh.add_vertex(mesh, {1.0, 2.0, 3.0})
      iex> Map.has_key?(mesh.vertices, id)
      true
  """
  @spec add_vertex(t(), Vertex.position(), keyword()) :: {t(), non_neg_integer()}
  def add_vertex(%__MODULE__{vertices: vertices, next_vertex_id: id} = mesh, position, opts \\ []) do
    vertex = Vertex.new(id, position, opts)
    new_vertices = Map.put(vertices, id, vertex)
    new_mesh = %{mesh | vertices: new_vertices, next_vertex_id: id + 1}
    {new_mesh, id}
  end

  @doc """
  Gets a vertex by ID.
  """
  @spec get_vertex(t(), non_neg_integer()) :: Vertex.t() | nil
  def get_vertex(%__MODULE__{vertices: vertices}, vertex_id) do
    Map.get(vertices, vertex_id)
  end

  @doc """
  Adds an edge to the mesh.

  Returns `{mesh, edge_id}` where `edge_id` is the newly assigned ID.
  """
  @spec add_edge(t(), {non_neg_integer(), non_neg_integer()}, keyword()) ::
          {t(), non_neg_integer()}
  def add_edge(%__MODULE__{edges: edges, next_edge_id: id} = mesh, vertices, opts \\ []) do
    edge = Edge.new(id, vertices, opts)

    # Update vertex edge connections
    {v1, v2} = vertices
    mesh = update_vertex_edge(mesh, v1, id)
    mesh = update_vertex_edge(mesh, v2, id)

    new_edges = Map.put(edges, id, edge)
    new_mesh = %{mesh | edges: new_edges, next_edge_id: id + 1}
    {new_mesh, id}
  end

  @doc """
  Gets an edge by ID.
  """
  @spec get_edge(t(), non_neg_integer()) :: Edge.t() | nil
  def get_edge(%__MODULE__{edges: edges}, edge_id) do
    Map.get(edges, edge_id)
  end

  @doc """
  Adds a loop to the mesh.

  Returns `{mesh, loop_id}` where `loop_id` is the newly assigned ID.
  """
  @spec add_loop(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {t(), non_neg_integer()}
  def add_loop(%__MODULE__{loops: loops, next_loop_id: id} = mesh, vertex, edge, face, opts \\ []) do
    loop = Loop.new(id, vertex, edge, face, opts)
    new_loops = Map.put(loops, id, loop)
    new_mesh = %{mesh | loops: new_loops, next_loop_id: id + 1}
    {new_mesh, id}
  end

  @doc """
  Gets a loop by ID.
  """
  @spec get_loop(t(), non_neg_integer()) :: Loop.t() | nil
  def get_loop(%__MODULE__{loops: loops}, loop_id) do
    Map.get(loops, loop_id)
  end

  @doc """
  Adds a face to the mesh.

  Returns `{mesh, face_id}` where `face_id` is the newly assigned ID.

  ## Examples

      iex> mesh = AriaBmesh.Mesh.new()
      iex> {mesh, _v1} = AriaBmesh.Mesh.add_vertex(mesh, {0.0, 0.0, 0.0})
      iex> {mesh, _v2} = AriaBmesh.Mesh.add_vertex(mesh, {1.0, 0.0, 0.0})
      iex> {mesh, _v3} = AriaBmesh.Mesh.add_vertex(mesh, {0.0, 1.0, 0.0})
      iex> {mesh, face_id} = AriaBmesh.Mesh.add_face(mesh, [0, 1, 2])
      iex> Map.has_key?(mesh.faces, face_id)
      true
  """
  @spec add_face(t(), [non_neg_integer()], keyword()) :: {t(), non_neg_integer()}
  def add_face(%__MODULE__{faces: faces, next_face_id: id} = mesh, vertices, opts \\ []) do
    face = Face.new(id, vertices, opts)
    new_faces = Map.put(faces, id, face)
    new_mesh = %{mesh | faces: new_faces, next_face_id: id + 1}
    {new_mesh, id}
  end

  @doc """
  Gets a face by ID.
  """
  @spec get_face(t(), non_neg_integer()) :: Face.t() | nil
  def get_face(%__MODULE__{faces: faces}, face_id) do
    Map.get(faces, face_id)
  end

  @doc """
  Gets all vertices as a list.
  """
  @spec vertices_list(t()) :: [Vertex.t()]
  def vertices_list(%__MODULE__{vertices: vertices}) do
    Map.values(vertices)
  end

  @doc """
  Gets all edges as a list.
  """
  @spec edges_list(t()) :: [Edge.t()]
  def edges_list(%__MODULE__{edges: edges}) do
    Map.values(edges)
  end

  @doc """
  Gets all loops as a list.
  """
  @spec loops_list(t()) :: [Loop.t()]
  def loops_list(%__MODULE__{loops: loops}) do
    Map.values(loops)
  end

  @doc """
  Gets all faces as a list.
  """
  @spec faces_list(t()) :: [Face.t()]
  def faces_list(%__MODULE__{faces: faces}) do
    Map.values(faces)
  end

  @doc """
  Gets the count of each topological element.
  """
  @spec counts(t()) :: %{
          vertices: non_neg_integer(),
          edges: non_neg_integer(),
          loops: non_neg_integer(),
          faces: non_neg_integer()
        }
  def counts(%__MODULE__{} = mesh) do
    %{
      vertices: map_size(mesh.vertices),
      edges: map_size(mesh.edges),
      loops: map_size(mesh.loops),
      faces: map_size(mesh.faces)
    }
  end

  # Private helper: Update vertex edge connection
  defp update_vertex_edge(%__MODULE__{vertices: vertices} = mesh, vertex_id, edge_id) do
    case Map.get(vertices, vertex_id) do
      nil ->
        mesh

      vertex ->
        updated_vertex = Vertex.add_edge(vertex, edge_id)
        new_vertices = Map.put(vertices, vertex_id, updated_vertex)
        %{mesh | vertices: new_vertices}
    end
  end
end

