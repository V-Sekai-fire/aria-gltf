# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaBmesh.Face do
  @moduledoc """
  BMesh face structure.

  A face represents a polygon (n-gon) with:
  - Vertices (variable-length list, supports n-gons)
  - Edges (variable-length list)
  - Loops (variable-length list, one per vertex)
  - Normal (face normal vector)
  - Attributes (HOLES for subdivision surfaces)

  Faces support non-triangular geometry (quads, n-gons).
  """

  @type position :: {float(), float(), float()}
  @type attributes :: %{String.t() => any()}
  @type t :: %__MODULE__{
          id: non_neg_integer(),
          vertices: [non_neg_integer()],
          edges: [non_neg_integer()],
          loops: [non_neg_integer()],
          normal: position() | nil,
          attributes: attributes()
        }

  @enforce_keys [:id, :vertices]
  defstruct [
    :id,
    :vertices,
    edges: [],
    loops: [],
    normal: nil,
    attributes: %{}
  ]

  @doc """
  Creates a new face.

  ## Parameters
  - `id`: Unique face identifier
  - `vertices`: List of vertex IDs (variable-length, supports n-gons)
  - `opts`: Optional keyword list with:
    - `edges`: List of edge IDs (default: [])
    - `loops`: List of loop IDs (default: [])
    - `normal`: Face normal as {x, y, z} tuple (default: nil)
    - `attributes`: Face attributes map (default: %{})

  ## Examples

      iex> AriaBmesh.Face.new(0, [1, 2, 3, 4])
      %AriaBmesh.Face{id: 0, vertices: [1, 2, 3, 4], edges: [], loops: []}

      iex> AriaBmesh.Face.new(0, [1, 2, 3], normal: {0.0, 0.0, 1.0})
      %AriaBmesh.Face{id: 0, vertices: [1, 2, 3], normal: {0.0, 0.0, 1.0}}
  """
  @spec new(non_neg_integer(), [non_neg_integer()], keyword()) :: t()
  def new(id, vertices, opts \\ []) when is_list(vertices) and length(vertices) >= 3 do
    %__MODULE__{
      id: id,
      vertices: vertices,
      edges: Keyword.get(opts, :edges, []),
      loops: Keyword.get(opts, :loops, []),
      normal: Keyword.get(opts, :normal),
      attributes: Keyword.get(opts, :attributes, %{})
    }
  end

  @doc """
  Gets the number of vertices (face degree).
  """
  @spec degree(t()) :: non_neg_integer()
  def degree(%__MODULE__{vertices: vertices}), do: length(vertices)

  @doc """
  Checks if the face is a triangle.
  """
  @spec triangle?(t()) :: boolean()
  def triangle?(%__MODULE__{vertices: vertices}), do: length(vertices) == 3

  @doc """
  Checks if the face is a quad.
  """
  @spec quad?(t()) :: boolean()
  def quad?(%__MODULE__{vertices: vertices}), do: length(vertices) == 4

  @doc """
  Checks if the face is an n-gon (more than 4 vertices).
  """
  @spec ngon?(t()) :: boolean()
  def ngon?(%__MODULE__{vertices: vertices}), do: length(vertices) > 4

  @doc """
  Gets a face attribute by name.

  ## Examples

      iex> face = %AriaBmesh.Face{attributes: %{"HOLES" => 0}}
      iex> AriaBmesh.Face.get_attribute(face, "HOLES")
      0
  """
  @spec get_attribute(t(), String.t()) :: any() | nil
  def get_attribute(%__MODULE__{attributes: attributes}, name) do
    Map.get(attributes, name)
  end

  @doc """
  Sets a face attribute.

  ## Examples

      iex> face = AriaBmesh.Face.new(0, [1, 2, 3, 4])
      iex> AriaBmesh.Face.set_attribute(face, "HOLES", 0)
      %AriaBmesh.Face{attributes: %{"HOLES" => 0}}
  """
  @spec set_attribute(t(), String.t(), any()) :: t()
  def set_attribute(%__MODULE__{} = face, name, value) do
    new_attributes = Map.put(face.attributes, name, value)
    %{face | attributes: new_attributes}
  end

  @doc """
  Adds an edge to the face.
  """
  @spec add_edge(t(), non_neg_integer()) :: t()
  def add_edge(%__MODULE__{edges: edges} = face, edge_id) do
    if edge_id in edges do
      face
    else
      %{face | edges: [edge_id | edges]}
    end
  end

  @doc """
  Adds a loop to the face.
  """
  @spec add_loop(t(), non_neg_integer()) :: t()
  def add_loop(%__MODULE__{loops: loops} = face, loop_id) do
    if loop_id in loops do
      face
    else
      %{face | loops: [loop_id | loops]}
    end
  end

  @doc """
  Sets the face normal.

  ## Examples

      iex> face = AriaBmesh.Face.new(0, [1, 2, 3])
      iex> AriaBmesh.Face.set_normal(face, {0.0, 0.0, 1.0})
      %AriaBmesh.Face{normal: {0.0, 0.0, 1.0}}
  """
  @spec set_normal(t(), position()) :: t()
  def set_normal(%__MODULE__{} = face, normal) when is_tuple(normal) and tuple_size(normal) == 3 do
    %{face | normal: normal}
  end

  @doc """
  Gets the normal as a list [x, y, z].
  """
  @spec normal_list(t()) :: [float()] | nil
  def normal_list(%__MODULE__{normal: nil}), do: nil
  def normal_list(%__MODULE__{normal: {x, y, z}}), do: [x, y, z]
end

