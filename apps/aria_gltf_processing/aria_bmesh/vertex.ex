# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaBmesh.Vertex do
  @moduledoc """
  BMesh vertex structure.

  A vertex represents a point in 3D space with:
  - Position (x, y, z coordinates)
  - Connected edges (variable-length list)
  - Attributes (POSITION, NORMAL, TANGENT, etc.)
  - Subdivision attributes (CREASE for subdivision surfaces)
  """

  @type position :: {float(), float(), float()}
  @type attributes :: %{String.t() => any()}
  @type t :: %__MODULE__{
          id: non_neg_integer(),
          position: position(),
          edges: [non_neg_integer()],
          attributes: attributes()
        }

  @enforce_keys [:id, :position]
  defstruct [
    :id,
    :position,
    edges: [],
    attributes: %{}
  ]

  @doc """
  Creates a new vertex.

  ## Parameters
  - `id`: Unique vertex identifier
  - `position`: 3D position as {x, y, z} tuple
  - `edges`: List of connected edge IDs (default: [])
  - `attributes`: Vertex attributes map (default: %{})

  ## Examples

      iex> AriaBmesh.Vertex.new(0, {1.0, 2.0, 3.0})
      %AriaBmesh.Vertex{id: 0, position: {1.0, 2.0, 3.0}, edges: [], attributes: %{}}
  """
  @spec new(non_neg_integer(), position(), keyword()) :: t()
  def new(id, position, opts \\ []) when is_tuple(position) and tuple_size(position) == 3 do
    %__MODULE__{
      id: id,
      position: position,
      edges: Keyword.get(opts, :edges, []),
      attributes: Keyword.get(opts, :attributes, %{})
    }
  end

  @doc """
  Gets the position coordinates as a list [x, y, z].
  """
  @spec position_list(t()) :: [float()]
  def position_list(%__MODULE__{position: {x, y, z}}), do: [x, y, z]

  @doc """
  Gets a vertex attribute by name.

  ## Examples

      iex> vertex = %AriaBmesh.Vertex{attributes: %{"NORMAL" => {0.0, 1.0, 0.0}}}
      iex> AriaBmesh.Vertex.get_attribute(vertex, "NORMAL")
      {0.0, 1.0, 0.0}
  """
  @spec get_attribute(t(), String.t()) :: any() | nil
  def get_attribute(%__MODULE__{attributes: attributes}, name) do
    Map.get(attributes, name)
  end

  @doc """
  Sets a vertex attribute.

  ## Examples

      iex> vertex = AriaBmesh.Vertex.new(0, {1.0, 2.0, 3.0})
      iex> AriaBmesh.Vertex.set_attribute(vertex, "NORMAL", {0.0, 1.0, 0.0})
      %AriaBmesh.Vertex{attributes: %{"NORMAL" => {0.0, 1.0, 0.0}}}
  """
  @spec set_attribute(t(), String.t(), any()) :: t()
  def set_attribute(%__MODULE__{} = vertex, name, value) do
    new_attributes = Map.put(vertex.attributes, name, value)
    %{vertex | attributes: new_attributes}
  end

  @doc """
  Adds an edge connection to the vertex.
  """
  @spec add_edge(t(), non_neg_integer()) :: t()
  def add_edge(%__MODULE__{edges: edges} = vertex, edge_id) do
    if edge_id in edges do
      vertex
    else
      %{vertex | edges: [edge_id | edges]}
    end
  end

  @doc """
  Removes an edge connection from the vertex.
  """
  @spec remove_edge(t(), non_neg_integer()) :: t()
  def remove_edge(%__MODULE__{edges: edges} = vertex, edge_id) do
    %{vertex | edges: List.delete(edges, edge_id)}
  end
end

