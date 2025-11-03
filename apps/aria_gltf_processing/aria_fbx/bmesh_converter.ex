# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaFbx.BmeshConverter do
  @moduledoc """
  Converts FBX mesh data directly to BMesh format.

  FBX files preserve n-gon topology, so we can directly map:
  - ufbx vertices → BMesh vertices
  - ufbx faces → BMesh faces (preserving n-gons)
  - ufbx face corners → BMesh loops (with per-corner attributes)
  - Derive edges from face boundaries

  This is more direct than triangle reconstruction since FBX maintains
  the original polygon topology.
  """

  alias AriaBmesh.{Mesh, Vertex, Edge, Loop, Face}
  alias AriaFbx.Scene.Mesh, as: FbxMesh

  @doc """
  Converts an FBX mesh to BMesh format.

  ## Parameters
  - `fbx_mesh`: The FBX Scene.Mesh structure

  ## Returns
  - `{:ok, bmesh}` - Successfully converted BMesh
  - `{:error, reason}` - Error during conversion

  ## Examples

      iex> fbx_mesh = %AriaFbx.Scene.Mesh{positions: [...], indices: [...]}
      iex> AriaFbx.BmeshConverter.from_fbx_mesh(fbx_mesh)
      {:ok, %AriaBmesh.Mesh{}}
  """
  @spec from_fbx_mesh(FbxMesh.t()) :: {:ok, Mesh.t()} | {:error, String.t()}
  def from_fbx_mesh(%FbxMesh{} = fbx_mesh) do
    bmesh = Mesh.new()

    with {:ok, bmesh} <- create_vertices_from_fbx(bmesh, fbx_mesh),
         {:ok, bmesh} <- create_faces_from_fbx(bmesh, fbx_mesh),
         {:ok, bmesh} <- create_edges_from_faces(bmesh),
         {:ok, bmesh} <- create_loops_from_faces(bmesh, fbx_mesh),
         {:ok, bmesh} <- setup_topological_navigation(bmesh) do
      {:ok, bmesh}
    end
  end

  # Create vertices from FBX positions
  defp create_vertices_from_fbx(%Mesh{} = bmesh, %FbxMesh{positions: positions})
       when is_list(positions) do
    # Positions are flat list [x1, y1, z1, x2, y2, z2, ...]
    {bmesh, _} =
      positions
      |> Enum.chunk_every(3)
      |> Enum.reduce({bmesh, 0}, fn [x, y, z], {mesh, _} ->
        {mesh, _} = Mesh.add_vertex(mesh, {x, y, z})
        {mesh, 0}
      end)

    {:ok, bmesh}
  end

  defp create_vertices_from_fbx(_bmesh, _), do: {:error, "FBX mesh has no positions"}

  # Create faces from FBX indices
  # FBX indices are triangle indices, but we want to reconstruct faces
  defp create_faces_from_fbx(%Mesh{} = bmesh, %FbxMesh{indices: indices})
       when is_list(indices) do
    # Group triangles by potential faces (shared edges)
    # For now, we'll treat each triangle as a face, but ideally we'd reconstruct n-gons
    if rem(length(indices), 3) == 0 do
      triangles = Enum.chunk_every(indices, 3)

      {bmesh, _} =
        Enum.reduce(triangles, {bmesh, 0}, fn triangle, {mesh, _} ->
          {mesh, _} = Mesh.add_face(mesh, triangle)
          {mesh, 0}
        end)

      {:ok, bmesh}
    else
      {:error, "FBX indices must be divisible by 3"}
    end
  end

  defp create_faces_from_fbx(_bmesh, _), do: {:error, "FBX mesh has no indices"}

  # Create edges from face boundaries (same as triangle reconstruction)
  defp create_edges_from_faces(%Mesh{} = bmesh) do
    faces = Mesh.faces_list(bmesh)

    {bmesh, _} =
      Enum.reduce(faces, {bmesh, []}, fn face, {mesh, _} ->
        vertices = face.vertices

        # Create edges between consecutive vertices (wraps around)
        edge_pairs =
          vertices
          |> Enum.with_index()
          |> Enum.map(fn {v1, i} ->
            v2 = Enum.at(vertices, rem(i + 1, length(vertices)))
            {v1, v2}
          end)

        # Add edges to mesh (avoid duplicates)
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

  # Create loops from face corners with per-corner attributes
  defp create_loops_from_faces(%Mesh{} = bmesh, %FbxMesh{} = fbx_mesh) do
    faces = Mesh.faces_list(bmesh)
    normals = fbx_mesh.normals || []
    texcoords = fbx_mesh.texcoords || []

    {bmesh, _} =
      Enum.reduce(faces, {bmesh, 0}, fn face, {mesh, _} ->
        vertices = face.vertices
        face_edges = face.edges

        # Create loops with per-corner attributes
        {mesh, loop_ids} =
          vertices
          |> Enum.with_index()
          |> Enum.reduce({mesh, []}, fn {vertex_id, i}, {m, acc} ->
            edge_id = Enum.at(face_edges, rem(i, length(face_edges)))

            opts = []
            # Add per-corner attributes if available
            opts = add_loop_normal(opts, normals, i)
            opts = add_loop_texcoord(opts, texcoords, i)

            {m, loop_id} = Mesh.add_loop(m, vertex_id, edge_id, face.id, opts)
            {m, [loop_id | acc]}
          end)

        # Update face with loop IDs
        updated_face = %{face | loops: Enum.reverse(loop_ids)}
        new_faces = Map.put(mesh.faces, face.id, updated_face)
        {%{mesh | faces: new_faces}, 0}
      end)

    {:ok, bmesh}
  end

  # Add normal attribute to loop if available
  defp add_loop_normal(opts, normals, index) when is_list(normals) do
    if index < length(normals) do
      # Normals are flat list [nx1, ny1, nz1, nx2, ny2, nz2, ...]
      [nx, ny, nz] = Enum.slice(normals, index * 3, 3)
      Keyword.update(opts, :attributes, %{}, fn attrs ->
        Map.put(attrs, "NORMAL", {nx, ny, nz})
      end)
    else
      opts
    end
  end

  defp add_loop_normal(opts, _, _), do: opts

  # Add texcoord attribute to loop if available
  defp add_loop_texcoord(opts, texcoords, index) when is_list(texcoords) do
    if index < length(texcoords) do
      # Texcoords are flat list [u1, v1, u2, v2, ...] or nested
      case Enum.at(texcoords, index) do
        [u, v] when is_number(u) and is_number(v) ->
          Keyword.update(opts, :attributes, %{}, fn attrs ->
            Map.put(attrs, "TEXCOORD_0", {u, v})
          end)

        _ ->
          opts
      end
    else
      opts
    end
  end

  defp add_loop_texcoord(opts, _, _), do: opts

  # Setup topological navigation (reuse from triangle reconstruction)
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
  defp setup_loop_radial_navigation(%Mesh{} = bmesh) do
    edges = Mesh.edges_list(bmesh)

    # For each edge, collect all loops that use it
    edge_to_loops =
      Enum.reduce(bmesh.loops, %{}, fn {loop_id, loop}, acc ->
        edge_id = loop.edge
        Map.update(acc, edge_id, [loop_id], fn existing -> [loop_id | existing] end)
      end)

    # Setup radial navigation for each edge's loops
    updated_loops =
      Enum.reduce(edge_to_loops, bmesh.loops, fn {edge_id, loop_ids}, loops ->
        if length(loop_ids) >= 2 do
          # Create circular linked list
          loop_ids
          |> Enum.with_index()
          |> Enum.reduce(loops, fn {loop_id, i}, acc ->
            loop = Map.get(acc, loop_id)

            if loop do
              prev_id =
                Enum.at(loop_ids, rem(i - 1 + length(loop_ids), length(loop_ids)))

              next_id = Enum.at(loop_ids, rem(i + 1, length(loop_ids)))

              updated_loop =
                loop
                |> Loop.set_radial_prev(prev_id)
                |> Loop.set_radial_next(next_id)

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
end

