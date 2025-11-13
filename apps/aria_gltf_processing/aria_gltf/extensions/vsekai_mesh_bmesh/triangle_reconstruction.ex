# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.VsekaiMeshBmesh.TriangleReconstruction do
  @moduledoc """
  Reconstruct BMesh from triangle meshes using triangle fan algorithm.

  This module implements the inverse of the triangle fan encoding algorithm,
  reconstructing original BMesh topology from glTF triangle indices.

  Algorithm Overview:
  1. Group triangles by shared anchor vertex (triangle fan detection)
  2. Rebuild faces from triangle fans
  3. Derive edges from face boundaries
  4. Create loops from face corners
  5. Set up topological navigation (next/prev/radial pointers)
  6. Verify topological consistency

  Critical Requirement: v(f) != v(f') for consecutive faces
  This ensures unambiguous reconstruction by requiring distinct anchor vertices.
  """

  alias AriaBmesh.{Mesh, Edge, Loop}
  alias AriaGltf.Document

  @doc """
  Reconstructs BMesh from glTF triangle mesh data.

  ## Parameters
  - `document`: The glTF document containing buffers and accessors
  - `primitive`: The glTF primitive with triangle indices and attributes
  - `positions`: List of vertex positions as {x, y, z} tuples
  - `indices`: List of triangle indices (u32 list, 3 indices per triangle)

  ## Returns
  - `{:ok, bmesh}` - Successfully reconstructed BMesh
  - `{:error, reason}` - Error during reconstruction

  ## Examples

      iex> positions = [{0.0, 0.0, 0.0}, {1.0, 0.0, 0.0}, {0.0, 1.0, 0.0}]
      iex> indices = [0, 1, 2]
      iex> AriaGltf.Extensions.VsekaiMeshBmesh.TriangleReconstruction.from_triangles(document, primitive, positions, indices)
      {:ok, %AriaBmesh.Mesh{}}
  """
  @spec from_triangles(
          Document.t(),
          AriaGltf.Mesh.Primitive.t(),
          [{float(), float(), float()}],
          [non_neg_integer()]
        ) :: {:ok, Mesh.t()} | {:error, String.t()}
  def from_triangles(%Document{} = _document, %AriaGltf.Mesh.Primitive{} = _primitive, positions, indices) do
    bmesh = Mesh.new()

    with {:ok, bmesh} <- create_vertices_from_positions(bmesh, positions),
         {:ok, triangles} <- validate_and_group_triangles(indices),
         {:ok, face_groups} <- group_triangles_by_anchor(triangles),
         {:ok, bmesh} <- create_faces_from_groups(bmesh, face_groups),
         {:ok, bmesh} <- create_edges_from_faces(bmesh),
         {:ok, bmesh} <- create_loops_from_faces(bmesh),
         {:ok, bmesh} <- setup_topological_navigation(bmesh) do
      {:ok, bmesh}
    end
  end

  # Create vertices from positions
  defp create_vertices_from_positions(%Mesh{} = bmesh, positions) do
    {bmesh, _} =
      Enum.reduce(positions, {bmesh, 0}, fn position, {mesh, _} ->
        {mesh, _} = Mesh.add_vertex(mesh, position)
        {mesh, 0}
      end)

    {:ok, bmesh}
  end

  # Validate and group triangles (must be divisible by 3)
  defp validate_and_group_triangles(indices) when is_list(indices) do
    if rem(length(indices), 3) == 0 do
      triangles =
        indices
        |> Enum.chunk_every(3)
        |> Enum.with_index()

      {:ok, triangles}
    else
      {:error, "Triangle indices must be divisible by 3"}
    end
  end

  defp validate_and_group_triangles(_), do: {:error, "Invalid triangle indices"}

  # Group triangles by shared anchor vertex (triangle fan detection)
  defp group_triangles_by_anchor(triangles) do
    # For each triangle, identify potential anchor vertices
    # Group triangles that share the same anchor vertex
    face_groups =
      triangles
      |> Enum.reduce(%{}, fn {[v0, v1, v2] = triangle, index}, acc ->
        # Check if any vertex appears in multiple triangles (potential anchor)
        anchors = [v0, v1, v2]

        # Find the anchor vertex for this triangle
        # The anchor is the vertex that appears first in previous triangles
        anchor = find_anchor_vertex(acc, anchors, index)

        Map.update(acc, anchor, [{triangle, index}], fn existing ->
          [{triangle, index} | existing]
        end)
      end)

    {:ok, face_groups}
  end

  # Find anchor vertex for a triangle
  # Must satisfy: v(f) != v(f') for consecutive faces
  defp find_anchor_vertex(existing_groups, candidates, current_index) do
    # If this is the first triangle, use minimum vertex as anchor
    if current_index == 0 do
      Enum.min(candidates)
    else
      # Find the previous face's anchor
      prev_anchor =
        existing_groups
        |> Map.values()
        |> List.flatten()
        |> Enum.find_value(fn {_triangle, idx} ->
          if idx == current_index - 1, do: find_prev_anchor(existing_groups, idx)
        end)

      # Choose anchor different from previous (v(f) != v(f') requirement)
      if prev_anchor && prev_anchor in candidates do
        # Choose a different candidate
        candidates
        |> Enum.filter(&(&1 != prev_anchor))
        |> then(fn filtered ->
          if Enum.empty?(filtered), do: Enum.min(candidates), else: Enum.min(filtered)
        end)
      else
        Enum.min(candidates)
      end
    end
  end

  # Find the anchor vertex used by a previous triangle group
  defp find_prev_anchor(existing_groups, triangle_index) do
    existing_groups
    |> Enum.find_value(fn {anchor, triangles} ->
      if Enum.any?(triangles, fn {_t, idx} -> idx == triangle_index end) do
        anchor
      end
    end)
  end

  # Create faces from triangle fan groups
  defp create_faces_from_groups(%Mesh{} = bmesh, face_groups) do
    {bmesh, _} =
      Enum.reduce(face_groups, {bmesh, 0}, fn {anchor, triangles}, {mesh, _} ->
        # Sort triangles by index to maintain order
        sorted_triangles =
          triangles
          |> Enum.sort_by(fn {_t, idx} -> idx end)
          |> Enum.map(fn {triangle, _idx} -> triangle end)

        # Reconstruct face vertices from triangle fan
        vertices = reconstruct_face_from_fan(anchor, sorted_triangles)

        {mesh, _face_id} = Mesh.add_face(mesh, vertices)
        {mesh, 0}
      end)

    {:ok, bmesh}
  end

  # Reconstruct face vertices from triangle fan
  # All triangles share the anchor vertex, forming a fan
  defp reconstruct_face_from_fan(anchor, triangles) when is_list(triangles) do
    # Extract unique vertices from triangles, starting with anchor
    vertices =
      triangles
      |> Enum.flat_map(fn triangle -> triangle end)
      |> Enum.uniq()
      |> Enum.sort()

    # Ensure anchor is first
    vertices = [anchor | (vertices -- [anchor])]
    vertices
  end

  # Create edges from face boundaries
  defp create_edges_from_faces(%Mesh{} = bmesh) do
    faces = Mesh.faces_list(bmesh)

    {bmesh, _} =
      Enum.reduce(faces, {bmesh, []}, fn face, {mesh, _face_edges_acc} ->
        vertices = face.vertices

        # Create edges between consecutive vertices (and wrap around)
        edge_pairs =
          vertices
          |> Enum.with_index()
          |> Enum.map(fn {v1, i} ->
            v2 = Enum.at(vertices, rem(i + 1, length(vertices)))
            {v1, v2}
          end)

        # Add edges to mesh (avoid duplicates) and collect edge IDs for face
        {mesh, edge_ids} =
          Enum.reduce(edge_pairs, {mesh, []}, fn {v1, v2}, {m, acc} ->
            # Normalize edge (smaller vertex first)
            {e1, e2} = if v1 < v2, do: {v1, v2}, else: {v2, v1}

            # Check if edge already exists
            existing_edge =
              Map.values(m.edges)
              |> Enum.find(fn edge ->
                edge.vertices == {e1, e2}
              end)

            if existing_edge do
              # Add face to existing edge
              updated_edge = Edge.add_face(existing_edge, face.id)
              new_edges = Map.put(m.edges, existing_edge.id, updated_edge)
              {%{m | edges: new_edges}, [existing_edge.id | acc]}
            else
              # Create new edge
              {m, edge_id} = Mesh.add_edge(m, {e1, e2}, faces: [face.id])
              {m, [edge_id | acc]}
            end
          end)

        # Update face with edge IDs
        updated_face = %{face | edges: Enum.reverse(edge_ids)}
        new_faces = Map.put(mesh.faces, face.id, updated_face)

        {%{mesh | faces: new_faces}, []}
      end)

    {:ok, bmesh}
  end

  # Create loops from face corners
  defp create_loops_from_faces(%Mesh{} = bmesh) do
    faces = Mesh.faces_list(bmesh)

    {bmesh, _} =
      Enum.reduce(faces, {bmesh, 0}, fn face, {mesh, _} ->
        vertices = face.vertices
        face_edges = face.edges

        # Create one loop per vertex
        # Each loop connects a vertex to its outgoing edge
        {mesh, loop_ids} =
          vertices
          |> Enum.with_index()
          |> Enum.reduce({mesh, []}, fn {vertex_id, i}, {m, acc} ->
            # Get the outgoing edge from this vertex (wraps around)
            edge_id = Enum.at(face_edges, rem(i, length(face_edges)))

            {m, loop_id} = Mesh.add_loop(m, vertex_id, edge_id, face.id)
            {m, [loop_id | acc]}
          end)

        # Update face with loop IDs
        updated_face = %{face | loops: Enum.reverse(loop_ids)}
        new_faces = Map.put(mesh.faces, face.id, updated_face)
        {%{mesh | faces: new_faces}, 0}
      end)

    {:ok, bmesh}
  end

  # Setup topological navigation (next/prev/radial pointers)
  defp setup_topological_navigation(%Mesh{} = bmesh) do
    # Set up next/prev pointers for loops within faces
    bmesh = setup_loop_face_navigation(bmesh)

    # Set up radial_next/radial_prev pointers for loops around edges
    bmesh = setup_loop_radial_navigation(bmesh)

    {:ok, bmesh}
  end

  # Setup next/prev navigation within faces
  defp setup_loop_face_navigation(%Mesh{} = bmesh) do
    faces = Mesh.faces_list(bmesh)

    updated_loops =
      Enum.reduce(faces, bmesh.loops, fn face, loops ->
        face_loops = face.loops

        if length(face_loops) >= 2 do
          face_loops
          |> Enum.with_index()
          |> Enum.reduce(loops, fn {loop_id, i}, acc ->
            loop = Map.get(acc, loop_id)

            if loop do
              prev_id = Enum.at(face_loops, rem(i - 1 + length(face_loops), length(face_loops)))
              next_id = Enum.at(face_loops, rem(i + 1, length(face_loops)))

              updated_loop =
                loop
                |> Loop.set_prev(prev_id)
                |> Loop.set_next(next_id)

              Map.put(acc, loop_id, updated_loop)
            else
              acc
            end
          end)
        else
          loops
        end
      end)

    %{bmesh | loops: updated_loops}
  end

  # Setup radial navigation around edges (non-manifold support)
  # Uses tombstones to detect and prevent cycles during setup
  defp setup_loop_radial_navigation(%Mesh{} = bmesh) do
    # For each edge, collect all loops that use it
    edge_to_loops =
      Enum.reduce(bmesh.loops, %{}, fn {loop_id, loop}, acc ->
        edge_id = loop.edge
        Map.update(acc, edge_id, [loop_id], fn existing -> [loop_id | existing] end)
      end)

    # Setup radial navigation for each edge's loops
    updated_loops =
      Enum.reduce(edge_to_loops, bmesh.loops, fn {_edge_id, loop_ids}, loops ->
        if length(loop_ids) >= 2 do
          # Use tombstones to detect cycles: track which loops we've already processed
          visited = MapSet.new()

          # Create circular linked list with cycle detection
          loop_ids
          |> Enum.with_index()
          |> Enum.reduce({loops, visited}, fn {loop_id, i}, {acc, visited_set} ->
            # Check tombstone: if we've already processed this loop, skip to prevent cycles
            if MapSet.member?(visited_set, loop_id) do
              # Cycle detected, skip this loop
              {acc, visited_set}
            else
              loop = Map.get(acc, loop_id)

              if loop do
                prev_id =
                  Enum.at(loop_ids, rem(i - 1 + length(loop_ids), length(loop_ids)))

                next_id = Enum.at(loop_ids, rem(i + 1, length(loop_ids)))

                updated_loop =
                  loop
                  |> Loop.set_radial_prev(prev_id)
                  |> Loop.set_radial_next(next_id)

                # Mark as visited (tombstone)
                new_visited = MapSet.put(visited_set, loop_id)
                {Map.put(acc, loop_id, updated_loop), new_visited}
              else
                {acc, visited_set}
              end
            end
          end)
          |> elem(0)
        else
          loops
        end
      end)

    %{bmesh | loops: updated_loops}
  end
end

