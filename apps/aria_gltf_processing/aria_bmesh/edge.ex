# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaBmesh.Edge do
  @moduledoc """
  BMesh edge structure.

  An edge connects two vertices and can be shared by multiple faces
  (non-manifold support). Edges store:
  - Two vertex references (always two vertices)
  - Adjacent faces (variable-length list, supports non-manifold)
  - Attributes (CREASE for subdivision surfaces)
  """

  @type attributes :: %{String.t() => any()}
  @type t :: %__MODULE__{
          id: non_neg_integer(),
          vertices: {non_neg_integer(), non_neg_integer()},
          faces: [non_neg_integer()],
          attributes: attributes()
        }

  @enforce_keys [:id, :vertices]
  defstruct [
    :id,
    :vertices,
    faces: [],
    attributes: %{}
  ]

  @doc """
  Creates a new edge.

  ## Parameters
  - `id`: Unique edge identifier
  - `vertices`: Tuple of two vertex IDs {v1, v2}
  - `faces`: List of adjacent face IDs (default: [])
  - `attributes`: Edge attributes map (default: %{})

  ## Examples

      iex> AriaBmesh.Edge.new(0, {1, 2})
      %AriaBmesh.Edge{id: 0, vertices: {1, 2}, faces: [], attributes: %{}}
  """
  @spec new(non_neg_integer(), {non_neg_integer(), non_neg_integer()}, keyword()) :: t()
  def new(id, vertices, opts \\ []) when is_tuple(vertices) and tuple_size(vertices) == 2 do
    %__MODULE__{
      id: id,
      vertices: vertices,
      faces: Keyword.get(opts, :faces, []),
      attributes: Keyword.get(opts, :attributes, %{})
    }
  end

  @doc """
  Gets an edge attribute by name.

  ## Examples

      iex> edge = %AriaBmesh.Edge{attributes: %{"CREASE" => 0.5}}
      iex> AriaBmesh.Edge.get_attribute(edge, "CREASE")
      0.5
  """
  @spec get_attribute(t(), String.t()) :: any() | nil
  def get_attribute(%__MODULE__{attributes: attributes}, name) do
    Map.get(attributes, name)
  end

  @doc """
  Sets an edge attribute.

  ## Examples

      iex> edge = AriaBmesh.Edge.new(0, {1, 2})
      iex> AriaBmesh.Edge.set_attribute(edge, "CREASE", 0.5)
      %AriaBmesh.Edge{attributes: %{"CREASE" => 0.5}}
  """
  @spec set_attribute(t(), String.t(), any()) :: t()
  def set_attribute(%__MODULE__{} = edge, name, value) do
    new_attributes = Map.put(edge.attributes, name, value)
    %{edge | attributes: new_attributes}
  end

  @doc """
  Adds a face connection to the edge (non-manifold support).
  """
  @spec add_face(t(), non_neg_integer()) :: t()
  def add_face(%__MODULE__{faces: faces} = edge, face_id) do
    if face_id in faces do
      edge
    else
      %{edge | faces: [face_id | faces]}
    end
  end

  @doc """
  Removes a face connection from the edge.
  """
  @spec remove_face(t(), non_neg_integer()) :: t()
  def remove_face(%__MODULE__{faces: faces} = edge, face_id) do
    %{edge | faces: List.delete(faces, face_id)}
  end

  @doc """
  Checks if the edge connects to a specific vertex.
  """
  @spec connects_to?(t(), non_neg_integer()) :: boolean()
  def connects_to?(%__MODULE__{vertices: {v1, v2}}, vertex_id) do
    vertex_id == v1 or vertex_id == v2
  end

  @doc """
  Gets the other vertex ID for an edge given one vertex.
  """
  @spec other_vertex(t(), non_neg_integer()) :: non_neg_integer() | nil
  def other_vertex(%__MODULE__{vertices: {v1, v2}}, vertex_id) do
    cond do
      vertex_id == v1 -> v2
      vertex_id == v2 -> v1
      true -> nil
    end
  end
end

