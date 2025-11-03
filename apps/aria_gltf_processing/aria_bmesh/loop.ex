# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaBmesh.Loop do
  @moduledoc """
  BMesh loop structure.

  A loop represents a corner of a face, connecting:
  - A vertex (corner position)
  - An edge (outgoing edge from the corner)
  - A face (containing face)
  
  Navigation pointers:
  - next: Next loop in the face boundary
  - prev: Previous loop in the face boundary
  - radial_next: Next loop around the edge (for non-manifold)
  - radial_prev: Previous loop around the edge (for non-manifold)
  
  Loops also store per-corner attributes (TEXCOORD_0, COLOR_0, etc.)
  """

  @type attributes :: %{String.t() => any()}
  @type t :: %__MODULE__{
          id: non_neg_integer(),
          vertex: non_neg_integer(),
          edge: non_neg_integer(),
          face: non_neg_integer(),
          next: non_neg_integer() | nil,
          prev: non_neg_integer() | nil,
          radial_next: non_neg_integer() | nil,
          radial_prev: non_neg_integer() | nil,
          attributes: attributes()
        }

  @enforce_keys [:id, :vertex, :edge, :face]
  defstruct [
    :id,
    :vertex,
    :edge,
    :face,
    :next,
    :prev,
    :radial_next,
    :radial_prev,
    attributes: %{}
  ]

  @doc """
  Creates a new loop.

  ## Parameters
  - `id`: Unique loop identifier
  - `vertex`: Vertex ID at this corner
  - `edge`: Edge ID (outgoing edge from corner)
  - `face`: Face ID containing this loop
  - `opts`: Optional keyword list with:
    - `next`: Next loop ID in face boundary
    - `prev`: Previous loop ID in face boundary
    - `radial_next`: Next loop ID around edge
    - `radial_prev`: Previous loop ID around edge
    - `attributes`: Loop attributes map

  ## Examples

      iex> AriaBmesh.Loop.new(0, 1, 2, 3)
      %AriaBmesh.Loop{id: 0, vertex: 1, edge: 2, face: 3, next: nil, prev: nil}
  """
  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), keyword()) ::
          t()
  def new(id, vertex, edge, face, opts \\ []) do
    %__MODULE__{
      id: id,
      vertex: vertex,
      edge: edge,
      face: face,
      next: Keyword.get(opts, :next),
      prev: Keyword.get(opts, :prev),
      radial_next: Keyword.get(opts, :radial_next),
      radial_prev: Keyword.get(opts, :radial_prev),
      attributes: Keyword.get(opts, :attributes, %{})
    }
  end

  @doc """
  Gets a loop attribute by name.

  Per-corner attributes like UVs and colors are stored on loops.

  ## Examples

      iex> loop = %AriaBmesh.Loop{attributes: %{"TEXCOORD_0" => {0.5, 0.5}}}
      iex> AriaBmesh.Loop.get_attribute(loop, "TEXCOORD_0")
      {0.5, 0.5}
  """
  @spec get_attribute(t(), String.t()) :: any() | nil
  def get_attribute(%__MODULE__{attributes: attributes}, name) do
    Map.get(attributes, name)
  end

  @doc """
  Sets a loop attribute.

  ## Examples

      iex> loop = AriaBmesh.Loop.new(0, 1, 2, 3)
      iex> AriaBmesh.Loop.set_attribute(loop, "TEXCOORD_0", {0.5, 0.5})
      %AriaBmesh.Loop{attributes: %{"TEXCOORD_0" => {0.5, 0.5}}}
  """
  @spec set_attribute(t(), String.t(), any()) :: t()
  def set_attribute(%__MODULE__{} = loop, name, value) do
    new_attributes = Map.put(loop.attributes, name, value)
    %{loop | attributes: new_attributes}
  end

  @doc """
  Sets the next loop pointer (face boundary navigation).
  """
  @spec set_next(t(), non_neg_integer() | nil) :: t()
  def set_next(%__MODULE__{} = loop, next_id), do: %{loop | next: next_id}

  @doc """
  Sets the previous loop pointer (face boundary navigation).
  """
  @spec set_prev(t(), non_neg_integer() | nil) :: t()
  def set_prev(%__MODULE__{} = loop, prev_id), do: %{loop | prev: prev_id}

  @doc """
  Sets the radial next pointer (edge navigation for non-manifold).
  """
  @spec set_radial_next(t(), non_neg_integer() | nil) :: t()
  def set_radial_next(%__MODULE__{} = loop, radial_next_id),
    do: %{loop | radial_next: radial_next_id}

  @doc """
  Sets the radial previous pointer (edge navigation for non-manifold).
  """
  @spec set_radial_prev(t(), non_neg_integer() | nil) :: t()
  def set_radial_prev(%__MODULE__{} = loop, radial_prev_id),
    do: %{loop | radial_prev: radial_prev_id}
end

