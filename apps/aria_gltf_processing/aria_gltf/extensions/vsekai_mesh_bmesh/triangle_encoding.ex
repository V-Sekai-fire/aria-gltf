# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.VsekaiMeshBmesh.TriangleEncoding do
  @moduledoc """
  Encode BMesh to triangles using triangle fan algorithm.

  This module implements the triangle fan encoding algorithm for backward
  compatibility with glTF 2.0 core specification (which only supports triangles).

  Algorithm Overview:
  1. For each BMesh face, select a distinct anchor vertex
  2. Generate triangle fan from anchor (ensuring v(f) != v(f') for consecutive faces)
  3. Output triangles in fan order for implicit reconstruction

  Critical Requirement: v(f) != v(f')
  Consecutive faces must have different anchor vertices to ensure unambiguous
  reconstruction when converting back to BMesh.
  """

  alias AriaBmesh.Mesh

  @doc """
  Encodes BMesh faces to triangle indices using triangle fan algorithm.

  ## Parameters
  - `bmesh`: The BMesh containing faces to encode
  - `opts`: Options:
    - `:ensure_distinct_anchors` - Ensure v(f) != v(f') (default: true)

  ## Returns
  - `{:ok, triangles}` - List of triangle indices [v1, v2, v3, v4, v5, v6, ...]
  - `{:error, reason}` - Error if anchor requirement cannot be satisfied

  ## Examples

      iex> bmesh = AriaBmesh.Mesh.new()
      iex> # ... add faces ...
      iex> AriaGltf.Extensions.VsekaiMeshBmesh.TriangleEncoding.from_bmesh(bmesh)
      {:ok, [0, 1, 2, 0, 2, 3, ...]}
  """
  @spec from_bmesh(Mesh.t(), keyword()) ::
          {:ok, [non_neg_integer()]} | {:error, String.t()}
  def from_bmesh(%Mesh{} = bmesh, opts \\ []) do
    ensure_distinct = Keyword.get(opts, :ensure_distinct_anchors, true)
    faces = Mesh.faces_list(bmesh) |> Enum.sort_by(& &1.id)

    triangles =
      faces
      |> Enum.reduce_while({[], nil}, fn face, {acc, prev_anchor} ->
        vertices = face.vertices

        if length(vertices) < 3 do
          {:halt, {:error, "Face #{face.id} has less than 3 vertices"}}
        else
          # Select anchor vertex (must be different from previous if ensuring distinct)
          anchor = select_anchor_vertex(vertices, prev_anchor, ensure_distinct)

          if ensure_distinct and anchor == prev_anchor and prev_anchor != nil and length(vertices) > 1 do
            {:halt, {:error, "Cannot ensure v(f) != v(f') for face #{face.id}"}}
          else
            # Generate triangle fan from anchor
            fan_triangles = generate_triangle_fan(vertices, anchor)
            {:cont, {acc ++ fan_triangles, anchor}}
          end
        end
      end)

    case triangles do
      {:error, reason} -> {:error, reason}
      {triangle_list, _} -> {:ok, List.flatten(triangle_list)}
    end
  end

  # Select anchor vertex for a face
  defp select_anchor_vertex(vertices, prev_anchor, ensure_distinct) do
    if ensure_distinct && prev_anchor != nil do
      # Filter out previous anchor
      candidates = Enum.filter(vertices, &(&1 != prev_anchor))

      if Enum.empty?(candidates) do
        # No alternative, use first vertex (will cause error if distinct required)
        Enum.at(vertices, 0)
      else
        Enum.min(candidates)
      end
    else
      # Use minimum vertex ID as anchor
      Enum.min(vertices)
    end
  end

  # Generate triangle fan from anchor vertex
  defp generate_triangle_fan(vertices, anchor) when length(vertices) >= 3 do
    # Find anchor index
    anchor_idx = Enum.find_index(vertices, &(&1 == anchor)) || 0
    n = length(vertices)

    # Create triangles: [anchor, v_i, v_{i+1}] for i = 1 to n-2
    1..(n - 2)
    |> Enum.map(fn i ->
      idx1 = rem(anchor_idx + i, n)
      idx2 = rem(anchor_idx + i + 1, n)

      v0 = Enum.at(vertices, anchor_idx)
      v1 = Enum.at(vertices, idx1)
      v2 = Enum.at(vertices, idx2)

      [v0, v1, v2]
    end)
  end

  @doc """
  Encodes BMesh to triangle positions and indices.

  Useful for creating standard glTF triangle meshes from BMesh.

  ## Parameters
  - `bmesh`: The BMesh to encode

  ## Returns
  - `{:ok, {positions, indices}}` - Positions as [{x, y, z}, ...] and indices as [i1, i2, i3, ...]
  """
  @spec to_triangle_mesh(Mesh.t()) ::
          {:ok, {[{float(), float(), float()}], [non_neg_integer()]}}
  def to_triangle_mesh(%Mesh{} = bmesh) do
    vertices = Mesh.vertices_list(bmesh)

    positions =
      vertices
      |> Enum.sort_by(& &1.id)
      |> Enum.map(& &1.position)

    with {:ok, indices} <- from_bmesh(bmesh) do
      {:ok, {positions, indices}}
    end
  end
end

