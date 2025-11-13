# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaDocument.Export.Obj do
  @moduledoc """
  Wavefront OBJ format exporter.

  Supports exporting both GLTFDocument and FBXDocument sources to OBJ format.
  Handles indexed and non-indexed geometry, materials, and multiple meshes.

  ## Features

  - Scene/node hierarchy traversal for glTF exports
  - Object groups (`g` commands) for organizing geometry by node hierarchy
  - Material groups (`usemtl` commands) with automatic change detection
  - BMesh format support for preserving topology
  - MTL material file generation with PBR material properties

  ## Scene Support

  For glTF documents, the exporter:
  - Traverses the scene/node hierarchy recursively
  - Creates object groups for each node (`g scene_name_node_name`)
  - Preserves material associations from primitives
  - Handles nested node hierarchies correctly

  ## Material Support

  Materials are exported to MTL files with:
  - Base color (diffuse) from PBR metallic-roughness
  - Specular approximation from metallic factor
  - Emissive properties
  - Automatic material group switching in OBJ faces
  """

  alias AriaGltf.BmeshConverter
  alias AriaBmesh.Mesh, as: Bmesh
  alias AriaFbx.Document, as: FBXDocument

  @doc """
  Exports a document (GLTF or FBX) to OBJ format.

  ## Options

  - `:mtl_file` - If true, generates an MTL material file (default: `true`)
  - `:base_path` - Base directory for output files (default: directory of obj_path)

  ## Examples

      {:ok, obj_path} = AriaDocument.Export.Obj.export(gltf_document, "/path/to/output.obj")
      {:ok, obj_path} = AriaDocument.Export.Obj.export(fbx_document, "/path/to/output.obj")

  ## ExDoc Improvements

  TODO: 2025-11-03 fire - Add more detailed examples showing:
  - Scene hierarchy export with multiple nodes
  - Material group handling
  - Error handling scenarios
  - Integration with BMesh format
  """
  @spec export(AriaGltf.Document.t() | FBXDocument.t() | map(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def export(document, obj_path, opts \\ [])

  def export(%AriaGltf.Document{} = document, obj_path, opts) do
    export_gltf(document, obj_path, opts)
  end

  def export(%FBXDocument{} = document, obj_path, opts) do
    export_fbx(document, obj_path, opts)
  end

  # Handle map-based documents (from test fixtures)
  def export(document, obj_path, opts) when is_map(document) do
    # Check if it's a glTF-like document (has asset or meshes)
    if Map.has_key?(document, :asset) or Map.has_key?(document, "asset") or
         Map.has_key?(document, :meshes) or Map.has_key?(document, "meshes") do
      export_gltf(document, obj_path, opts)
    # Check if it's an FBX-like document (has version or nodes)
    else
      if Map.has_key?(document, :version) or Map.has_key?(document, "version") or
           Map.has_key?(document, :nodes) or Map.has_key?(document, "nodes") do
        export_fbx(document, obj_path, opts)
      else
        {:error, :unsupported_document_type}
      end
    end
  end

  def export(_, _, _), do: {:error, :unsupported_document_type}

  defp export_gltf(document, obj_path, opts) when is_map(document) do
    mtl_enabled = Keyword.get(opts, :mtl_file, true)
    base_path = Keyword.get(opts, :base_path, Path.dirname(obj_path))

    with :ok <- ensure_directory_exists(obj_path),
         {:ok, obj_content} <- generate_obj_content_gltf(document, obj_path),
         :ok <- File.write(obj_path, obj_content) do
      if mtl_enabled do
        mtl_path = obj_path |> Path.rootname() |> Kernel.<>(".mtl")
        case generate_mtl_content_gltf(document, base_path) do
          {:ok, mtl_content} ->
            File.write(mtl_path, mtl_content)
            {:ok, obj_path}

          error ->
            error
        end
      else
        {:ok, obj_path}
      end
    end
  end

  defp export_gltf(%AriaGltf.Document{} = document, obj_path, opts) do
    mtl_enabled = Keyword.get(opts, :mtl_file, true)
    base_path = Keyword.get(opts, :base_path, Path.dirname(obj_path))

    with :ok <- ensure_directory_exists(obj_path),
         {:ok, obj_content} <- generate_obj_content_gltf(document, obj_path),
         :ok <- File.write(obj_path, obj_content) do
      if mtl_enabled do
        mtl_path = obj_path |> Path.rootname() |> Kernel.<>(".mtl")
        case generate_mtl_content_gltf(document, base_path) do
          {:ok, mtl_content} ->
            File.write(mtl_path, mtl_content)
            {:ok, obj_path}

          error ->
            error
        end
      else
        {:ok, obj_path}
      end
    end
  end

  defp export_fbx(%FBXDocument{} = document, obj_path, opts) do
    mtl_enabled = Keyword.get(opts, :mtl_file, true)
    base_path = Keyword.get(opts, :base_path, Path.dirname(obj_path))

    with :ok <- ensure_directory_exists(obj_path),
         {:ok, obj_content} <- generate_obj_content_fbx(document, obj_path),
         :ok <- File.write(obj_path, obj_content) do
      if mtl_enabled do
        mtl_path = obj_path |> Path.rootname() |> Kernel.<>(".mtl")
        case generate_mtl_content_fbx(document, base_path) do
          {:ok, mtl_content} ->
            File.write(mtl_path, mtl_content)
            {:ok, obj_path}

          error ->
            error
        end
      else
        {:ok, obj_path}
      end
    end
  end

  defp ensure_directory_exists(file_path) do
    dir = Path.dirname(file_path)
    File.mkdir_p(dir)
  end

  defp generate_obj_content_gltf(document, obj_path) when is_map(document) do
    obj_lines = [
      "# OBJ file exported from glTF",
      "# Generated by AriaGltf"
    ]

    # Add MTL reference if materials exist
    materials = Map.get(document, :materials) || Map.get(document, "materials") || []
    obj_lines = if is_list(materials) and length(materials) > 0 do
      mtl_name = Path.basename(obj_path |> Path.rootname(), ".obj")
      obj_lines ++ ["mtllib #{mtl_name}.mtl"]
    else
      obj_lines
    end

    # Track vertex offsets for multiple meshes
    vertex_offset = 0
    normal_offset = 0
    texcoord_offset = 0

    # Extract scenes/nodes with hierarchy
    {obj_lines, _vertex_offset, _normal_offset, _texcoord_offset, _current_material} =
      extract_scenes_to_obj(document, obj_lines, vertex_offset, normal_offset, texcoord_offset)

    {:ok, Enum.join(obj_lines, "\n") <> "\n"}
  end

  defp generate_obj_content_gltf(%AriaGltf.Document{} = document, obj_path) do
    obj_lines = [
      "# OBJ file exported from glTF",
      "# Generated by AriaGltf"
    ]

    # Add MTL reference if materials exist
    obj_lines = if document.materials && length(document.materials) > 0 do
      mtl_name = Path.basename(obj_path |> Path.rootname(), ".obj")
      obj_lines ++ ["mtllib #{mtl_name}.mtl"]
    else
      obj_lines
    end

    # Track vertex offsets for multiple meshes
    vertex_offset = 0
    normal_offset = 0
    texcoord_offset = 0

    # Extract scenes/nodes with hierarchy
    {obj_lines, _vertex_offset, _normal_offset, _texcoord_offset, _current_material} =
      extract_scenes_to_obj(document, obj_lines, vertex_offset, normal_offset, texcoord_offset)

    {:ok, Enum.join(obj_lines, "\n") <> "\n"}
  end

  defp generate_obj_content_fbx(%FBXDocument{} = document, obj_path) do
    obj_lines = [
      "# OBJ file exported from FBX",
      "# Generated by AriaFbx"
    ]

    # Add MTL reference if materials exist
    obj_lines = if document.materials && length(document.materials) > 0 do
      mtl_name = Path.basename(obj_path |> Path.rootname(), ".obj")
      obj_lines ++ ["mtllib #{mtl_name}.mtl"]
    else
      obj_lines
    end

    # Extract meshes from FBX document
    {obj_lines, _vertex_offset, _normal_offset, _texcoord_offset} =
      extract_meshes_from_fbx(document, obj_lines, 0, 0, 0)

    {:ok, Enum.join(obj_lines, "\n") <> "\n"}
  end

  # Extract scenes and nodes to OBJ format with hierarchy preservation
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - Scene traversal algorithm
  # - Offset tracking across multiple meshes
  # - Fallback behavior when no scene exists
  @doc false
  defp extract_scenes_to_obj(document, obj_lines, vertex_offset, normal_offset, texcoord_offset) when is_map(document) do
    case get_default_scene(document) do
      nil ->
        # No scene available, fall back to old method
        {old_lines, old_v, old_n, old_t} =
          extract_meshes_from_gltf(document, obj_lines, vertex_offset, normal_offset,
            texcoord_offset)

        # Return with nil material for backward compatibility
        {old_lines, old_v, old_n, old_t, nil}

      scene when is_map(scene) ->
        # Process scene root nodes
        root_nodes = get_scene_nodes(scene)
        scene_name = Map.get(scene, :name) || Map.get(scene, "name") || "scene_0"
        root_nodes_list = if is_list(root_nodes), do: root_nodes, else: []

        Enum.reduce(root_nodes_list, {obj_lines, vertex_offset, normal_offset, texcoord_offset, nil},
          fn node_index, {lines, v_off, n_off, t_off, current_mtl} ->
            extract_node_to_obj(document, node_index, [scene_name], lines, v_off, n_off, t_off,
              current_mtl)
          end)
    end
  end

  defp extract_scenes_to_obj(document, obj_lines, vertex_offset, normal_offset, texcoord_offset) do
    case get_default_scene(document) do
      nil ->
        # No scene available, fall back to old method
        {old_lines, old_v, old_n, old_t} =
          extract_meshes_from_gltf(document, obj_lines, vertex_offset, normal_offset,
            texcoord_offset)

        # Return with nil material for backward compatibility
        {old_lines, old_v, old_n, old_t, nil}

      scene ->
        # Process scene root nodes
        root_nodes = get_scene_nodes(scene)
        scene_name = scene.name || "scene_0"

        Enum.reduce(root_nodes, {obj_lines, vertex_offset, normal_offset, texcoord_offset, nil},
          fn node_index, {lines, v_off, n_off, t_off, current_mtl} ->
            extract_node_to_obj(document, node_index, [scene_name], lines, v_off, n_off, t_off,
              current_mtl)
          end)
    end
  end

  # Recursively extract node and its children with hierarchy preservation
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - Node hierarchy traversal
  # - Object group naming convention
  # - Material tracking across node tree
  # - Child node recursion pattern
  @doc false
  defp extract_node_to_obj(
         document,
         node_index,
         node_path,
         obj_lines,
         vertex_offset,
         normal_offset,
         texcoord_offset,
         current_material
       ) when is_map(document) do
    nodes = Map.get(document, :nodes) || Map.get(document, "nodes") || []
    nodes_list = if is_list(nodes), do: nodes, else: []

    case Enum.at(nodes_list, node_index) do
      nil ->
        # Invalid node index, return unchanged
        {obj_lines, vertex_offset, normal_offset, texcoord_offset, current_material}

      node when is_map(node) ->
        # Build updated node path
        node_name = Map.get(node, :name) || Map.get(node, "name")
        updated_path = build_node_path(node_path, node_index, node_name)

        # Add object group
        group_name = Enum.join(updated_path, "_")
        lines = obj_lines ++ ["", "g #{group_name}"]

        # Extract mesh if node has one
        mesh_index = Map.get(node, :mesh) || Map.get(node, "mesh")
        {lines, v_off, n_off, t_off, current_mtl} =
          if mesh_index do
            extract_mesh_to_obj(document, mesh_index, updated_path, lines, vertex_offset,
              normal_offset, texcoord_offset, current_material)
          else
            {lines, vertex_offset, normal_offset, texcoord_offset, current_material}
          end

        # Recursively process children
        children = Map.get(node, :children) || Map.get(node, "children") || []
        children_list = if is_list(children), do: children, else: []
        {final_lines, final_v_off, final_n_off, final_t_off, final_mtl} =
          Enum.reduce(children_list,
            {lines, v_off, n_off, t_off, current_mtl},
            fn child_index, {acc_lines, acc_v, acc_n, acc_t, acc_mtl} ->
              extract_node_to_obj(document, child_index, updated_path, acc_lines, acc_v, acc_n,
                acc_t, acc_mtl)
            end)

        {final_lines, final_v_off, final_n_off, final_t_off, final_mtl}
    end
  end

  defp extract_node_to_obj(
         document,
         node_index,
         node_path,
         obj_lines,
         vertex_offset,
         normal_offset,
         texcoord_offset,
         current_material
       ) do
    nodes = document.nodes || []

    case Enum.at(nodes, node_index) do
      nil ->
        # Invalid node index, return unchanged
        {obj_lines, vertex_offset, normal_offset, texcoord_offset, current_material}

      node ->
        # Build updated node path
        updated_path = build_node_path(node_path, node_index, node.name)

        # Add object group
        group_name = Enum.join(updated_path, "_")
        lines = obj_lines ++ ["", "g #{group_name}"]

        # Extract mesh if node has one
        {lines, v_off, n_off, t_off, current_mtl} =
          if node.mesh do
            extract_mesh_to_obj(document, node.mesh, updated_path, lines, vertex_offset,
              normal_offset, texcoord_offset, current_material)
          else
            {lines, vertex_offset, normal_offset, texcoord_offset, current_material}
          end

        # Recursively process children
        {final_lines, final_v_off, final_n_off, final_t_off, final_mtl} =
          Enum.reduce(node.children || [],
            {lines, v_off, n_off, t_off, current_mtl},
            fn child_index, {acc_lines, acc_v, acc_n, acc_t, acc_mtl} ->
              extract_node_to_obj(document, child_index, updated_path, acc_lines, acc_v, acc_n,
                acc_t, acc_mtl)
            end)

        {final_lines, final_v_off, final_n_off, final_t_off, final_mtl}
    end
  end

  # Extract mesh and its primitives with material tracking
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - Primitive-to-BMesh conversion
  # - Material association per primitive
  # - Multi-primitive mesh handling
  @doc false
  defp extract_mesh_to_obj(
         document,
         mesh_index,
         node_path,
         obj_lines,
         vertex_offset,
         normal_offset,
         texcoord_offset,
         current_material
       ) when is_map(document) do
    meshes = Map.get(document, :meshes) || Map.get(document, "meshes") || []
    meshes_list = if is_list(meshes), do: meshes, else: []

    case Enum.at(meshes_list, mesh_index) do
      nil ->
        # Invalid mesh index, return unchanged
        {obj_lines, vertex_offset, normal_offset, texcoord_offset, current_material}

      mesh when is_map(mesh) ->
        primitives = Map.get(mesh, :primitives) || Map.get(mesh, "primitives") || []
        primitives_list = if is_list(primitives), do: primitives, else: []

        Enum.reduce(primitives_list,
          {obj_lines, vertex_offset, normal_offset, texcoord_offset, current_material},
          fn primitive, {acc_lines, acc_v, acc_n, acc_t, acc_mtl} ->
            # Convert primitive to BMesh
            case BmeshConverter.convert_primitive_to_bmesh(document, primitive) do
              {:ok, bmesh} ->
                material_index = Map.get(primitive, :material) || Map.get(primitive, "material")
                extract_primitive_bmesh_to_obj(bmesh, material_index, document, node_path,
                  acc_lines, acc_v, acc_n, acc_t, acc_mtl)

              {:error, _reason} ->
                # Skip failed primitives
                {acc_lines, acc_v, acc_n, acc_t, acc_mtl}
            end
          end)
    end
  end

  defp extract_mesh_to_obj(
         document,
         mesh_index,
         node_path,
         obj_lines,
         vertex_offset,
         normal_offset,
         texcoord_offset,
         current_material
       ) do
    meshes = document.meshes || []

    case Enum.at(meshes, mesh_index) do
      nil ->
        # Invalid mesh index, return unchanged
        {obj_lines, vertex_offset, normal_offset, texcoord_offset, current_material}

      mesh ->
        primitives = mesh.primitives || []

        Enum.reduce(primitives,
          {obj_lines, vertex_offset, normal_offset, texcoord_offset, current_material},
          fn primitive, {acc_lines, acc_v, acc_n, acc_t, acc_mtl} ->
            # Convert primitive to BMesh
            case BmeshConverter.convert_primitive_to_bmesh(document, primitive) do
              {:ok, bmesh} ->
                extract_primitive_bmesh_to_obj(bmesh, primitive.material, document, node_path,
                  acc_lines, acc_v, acc_n, acc_t, acc_mtl)

              {:error, _reason} ->
                # Skip failed primitives
                {acc_lines, acc_v, acc_n, acc_t, acc_mtl}
            end
          end)
    end
  end

  # Extract primitive BMesh with material support
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - BMesh geometry extraction (vertices, normals, texcoords)
  # - Material name resolution
  # - Vertex offset management
  @doc false
  defp extract_primitive_bmesh_to_obj(
         bmesh,
         material_index,
         document,
         _node_path,
         obj_lines,
         vertex_offset,
         normal_offset,
         texcoord_offset,
         current_material
       ) do
    # Get material name
    material_name = get_material_name(document, material_index)

    # Write vertices from BMesh
    vertices = Bmesh.vertices_list(bmesh) |> Enum.sort_by(& &1.id)
    {new_lines, new_v_off} = write_vertices_from_bmesh(vertices, obj_lines, vertex_offset)

    # Write normals from BMesh
    {new_lines, new_n_off} = write_normals_from_bmesh(bmesh, new_lines, normal_offset)

    # Write texture coordinates from BMesh
    {new_lines, new_t_off} = write_texcoords_from_bmesh(bmesh, new_lines, texcoord_offset)

    # Write faces with material
    {final_lines, updated_material} =
      write_faces_with_material(bmesh, material_name, new_lines, new_v_off, new_n_off, new_t_off,
        current_material)

    {final_lines, new_v_off, new_n_off, new_t_off, updated_material}
  end

  # Old method kept for backward compatibility
  defp extract_meshes_from_gltf(document, obj_lines, vertex_offset, normal_offset, texcoord_offset) do
    # Convert glTF document to BMesh
    case BmeshConverter.from_gltf_document(document) do
      {:ok, bmeshes} ->
        # Process each BMesh
        Enum.reduce(bmeshes, {obj_lines, vertex_offset, normal_offset, texcoord_offset}, fn bmesh,
                                                                                             {_lines, _v_off,
                                                                                              _n_off, _t_off} ->
          extract_bmesh_to_obj(bmesh, obj_lines, vertex_offset, normal_offset, texcoord_offset)
        end)

      error ->
        # If conversion fails, return current state
        # Note: error can be {:error, reason} but compiler may infer it never matches
        # This is a fallback for when BMesh conversion is not available
        _ = error
        {obj_lines, vertex_offset, normal_offset, texcoord_offset}
    end
  end

  # Extract BMesh geometry to OBJ format
  defp extract_bmesh_to_obj(%Bmesh{} = bmesh, obj_lines, vertex_offset, normal_offset,
         texcoord_offset) do
    # Add object name
    lines = obj_lines ++ [""]

    # Extract vertices from BMesh
    vertices = Bmesh.vertices_list(bmesh) |> Enum.sort_by(& &1.id)
    {new_lines, new_v_off} = write_vertices_from_bmesh(vertices, lines, vertex_offset)
    lines = new_lines
    v_off = new_v_off

    # Extract normals (from vertex attributes or face normals)
    {new_lines, new_n_off} = write_normals_from_bmesh(bmesh, lines, normal_offset)
    lines = new_lines
    n_off = new_n_off

    # Extract texture coordinates (from loop attributes)
    {new_lines, new_t_off} = write_texcoords_from_bmesh(bmesh, lines, texcoord_offset)
    lines = new_lines
    t_off = new_t_off

    # Extract faces
    lines = write_faces_from_bmesh(bmesh, lines, v_off, n_off, t_off)

    {lines, v_off, n_off, t_off}
  end

  # Write vertices from BMesh
  defp write_vertices_from_bmesh(vertices, lines, offset) do
    vertex_lines =
      vertices
      |> Enum.map(fn vertex ->
        {x, y, z} = vertex.position
        "v #{x} #{y} #{z}"
      end)

    {lines ++ vertex_lines, offset + length(vertex_lines)}
  end

  # Write normals from BMesh (from vertex attributes or face normals)
  defp write_normals_from_bmesh(%Bmesh{} = bmesh, lines, offset) do
    # Try to get normals from vertex attributes first
    vertices = Bmesh.vertices_list(bmesh) |> Enum.sort_by(& &1.id)

    normals =
      vertices
      |> Enum.map(fn vertex ->
        case AriaBmesh.Vertex.get_attribute(vertex, "NORMAL") do
          nil -> nil
          normal -> normal
        end
      end)

    # If no vertex normals, use face normals
    if Enum.all?(normals, &is_nil/1) do
      faces = Bmesh.faces_list(bmesh) |> Enum.sort_by(& &1.id)

      normal_lines =
        faces
        |> Enum.map(fn face ->
          case face.normal do
            nil -> nil
            {x, y, z} -> "vn #{x} #{y} #{z}"
          end
        end)
        |> Enum.reject(&is_nil/1)

      {lines ++ normal_lines, offset + length(normal_lines)}
    else
      normal_lines =
        normals
        |> Enum.map(fn
          nil -> nil
          {x, y, z} -> "vn #{x} #{y} #{z}"
        end)
        |> Enum.reject(&is_nil/1)

      {lines ++ normal_lines, offset + length(normal_lines)}
    end
  end

  # Write texture coordinates from BMesh loops
  defp write_texcoords_from_bmesh(%Bmesh{} = bmesh, lines, offset) do
    loops = Bmesh.loops_list(bmesh) |> Enum.sort_by(& &1.id)

    texcoord_lines =
      loops
      |> Enum.map(fn loop ->
        case AriaBmesh.Loop.get_attribute(loop, "TEXCOORD_0") do
          nil -> nil
          {u, v} -> "vt #{u} #{v}"
          [u, v] -> "vt #{u} #{v}"
        end
      end)
      |> Enum.reject(&is_nil/1)

    {lines ++ texcoord_lines, offset + length(texcoord_lines)}
  end

  # Write faces from BMesh with material group support
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - Material change detection algorithm
  # - OBJ face format (v/vt/vn indices)
  # - When usemtl commands are emitted
  @doc false
  defp write_faces_with_material(
         %Bmesh{} = bmesh,
         material_name,
         lines,
         vertex_offset,
         _normal_offset,
         texcoord_offset,
         current_material
       ) do
    faces = Bmesh.faces_list(bmesh) |> Enum.sort_by(& &1.id)

    # Check if material changed
    updated_lines =
      cond do
        material_name == nil ->
          # No material, don't emit usemtl
          lines

        material_name == current_material ->
          # Material hasn't changed, don't emit usemtl
          lines

        true ->
          # Material changed, emit usemtl
          lines ++ ["usemtl #{material_name}"]
      end

    # Generate face lines
    face_lines =
      Enum.map(faces, fn face ->
        # Get vertex indices for this face
        vertex_indices = Enum.map(face.vertices, fn v -> v + vertex_offset + 1 end)

        # Get loop indices for texture coordinates
        loop_indices = face.loops

        # Build face string with vertex/normal/texcoord references
        # Note: OBJ format uses v/vt/vn but we'll keep it simple for now
        # and match the existing implementation pattern
        if length(loop_indices) > 0 and texcoord_offset > 0 do
          # Has texture coordinates
          face_verts =
            Enum.with_index(vertex_indices)
            |> Enum.map(fn {v_idx, i} ->
              loop_idx = Enum.at(loop_indices, i)
              texcoord_idx = if loop_idx, do: loop_idx + texcoord_offset + 1, else: nil

              if texcoord_idx do
                "#{v_idx}/#{texcoord_idx}"
              else
                "#{v_idx}"
              end
            end)
            |> Enum.join(" ")

          "f #{face_verts}"
        else
          # No texture coordinates
          face_verts = Enum.map(vertex_indices, fn v -> "#{v}" end) |> Enum.join(" ")
          "f #{face_verts}"
        end
      end)

    {updated_lines ++ face_lines, material_name}
  end

  # Write faces from BMesh (backward compatibility)
  defp write_faces_from_bmesh(%Bmesh{} = bmesh, lines, vertex_offset, normal_offset,
         texcoord_offset) do
    {face_lines, _} = write_faces_with_material(bmesh, nil, [], vertex_offset, normal_offset,
      texcoord_offset, nil)

    lines ++ face_lines
  end

  defp extract_meshes_from_fbx(document, obj_lines, vertex_offset, normal_offset, texcoord_offset) do
    meshes = document.meshes || []

    Enum.reduce(meshes, {obj_lines, vertex_offset, normal_offset, texcoord_offset}, fn mesh,
                                                                                      acc ->
      {lines, v_off, n_off, t_off} = acc
      # Add object name
      mesh_name = mesh.name || "mesh_#{mesh.id}"
      lines = lines ++ ["", "o #{mesh_name}"]

      # Extract vertices
      {lines, v_off} =
        if mesh.positions do
          {new_lines, new_v_off} = write_vertices(mesh.positions, lines, v_off)
          {new_lines, new_v_off}
        else
          {lines, v_off}
        end

      # Extract normals
      {lines, n_off} =
        if mesh.normals do
          {new_lines, new_n_off} = write_normals(mesh.normals, lines, n_off)
          {new_lines, new_n_off}
        else
          {lines, n_off}
        end

      # Extract texture coordinates
      {lines, t_off} =
        if mesh.texcoords do
          {new_lines, new_t_off} = write_texcoords(mesh.texcoords, lines, t_off)
          {new_lines, new_t_off}
        else
          {lines, t_off}
        end

      # Extract faces
      lines =
        if mesh.indices && mesh.positions do
          write_faces(mesh.indices, lines, v_off, n_off, t_off, mesh.material_ids)
        else
          lines
        end

      {lines, v_off, n_off, t_off}
    end)
  end

  defp write_vertices(positions, lines, offset) do
    # Positions are flat list [x1, y1, z1, x2, y2, z2, ...]
    vertex_lines =
      positions
      |> Enum.chunk_every(3)
      |> Enum.map(fn [x, y, z] -> "v #{x} #{y} #{z}" end)

    {lines ++ vertex_lines, offset + length(vertex_lines)}
  end

  defp write_normals(normals, lines, offset) do
    # Normals are flat list [nx1, ny1, nz1, nx2, ny2, nz2, ...]
    normal_lines =
      normals
      |> Enum.chunk_every(3)
      |> Enum.map(fn [nx, ny, nz] -> "vn #{nx} #{ny} #{nz}" end)

    {lines ++ normal_lines, offset + length(normal_lines)}
  end

  defp write_texcoords(texcoords, lines, offset) do
    # Texcoords are flat list [u1, v1, u2, v2, ...] or nested [[u1, v1], [u2, v2], ...]
    texcoord_lines =
      texcoords
      |> Enum.chunk_every(2)
      |> Enum.map(fn [u, v] -> "vt #{u} #{v}" end)

    {lines ++ texcoord_lines, offset + length(texcoord_lines)}
  end

  defp write_faces(indices, lines, vertex_offset, normal_offset, texcoord_offset, material_ids) do
    # Group indices into triangles (FBX indices are typically triangles)
    # OBJ supports triangles (3 vertices) and quads (4 vertices)
    face_lines =
      if length(indices) > 0 do
        # Check if we have quads (divisible by 4) or triangles (divisible by 3)
        cond do
          rem(length(indices), 4) == 0 ->
            # Try quads first
            generate_quad_faces(indices, vertex_offset, normal_offset, texcoord_offset,
              material_ids)

          rem(length(indices), 3) == 0 ->
            # Triangles
            generate_triangle_faces(indices, vertex_offset, normal_offset, texcoord_offset,
              material_ids)

          true ->
            # Invalid index count, try to process what we can as triangles
            triangle_count = div(length(indices), 3)
            available_indices = Enum.take(indices, triangle_count * 3)

            generate_triangle_faces(available_indices, vertex_offset, normal_offset,
              texcoord_offset, material_ids)
        end
      else
        []
      end

    lines ++ face_lines
  end

  # Generate triangle faces from indices
  defp generate_triangle_faces(indices, vertex_offset, normal_offset, texcoord_offset,
         material_ids) do
    triangles = Enum.chunk_every(indices, 3)

    {face_lines, _} =
      triangles
      |> Enum.with_index()
      |> Enum.reduce({[], nil}, fn {triangle, triangle_index}, {acc, current_material} ->
        # Get material for this triangle (if material_ids provided)
        material_id =
          if material_ids && length(material_ids) > 0 do
            Enum.at(material_ids, triangle_index)
          else
            nil
          end

        # Convert triangle indices to OBJ format (1-based)
        face_line =
          triangle
          |> Enum.map(fn vertex_idx ->
            # OBJ uses 1-based indexing
            v_idx = vertex_idx + vertex_offset + 1

            # Build face vertex reference: v/vt/vn, v/vt, or v
            cond do
              normal_offset > 0 && texcoord_offset > 0 ->
                # Has both normals and texture coordinates
                # For FBX, we use vertex index for both normal and texcoord (indexed per vertex)
                normal_idx = v_idx
                texcoord_idx = vertex_idx + texcoord_offset + 1
                "#{v_idx}/#{texcoord_idx}/#{normal_idx}"

              texcoord_offset > 0 ->
                # Has texture coordinates only
                texcoord_idx = vertex_idx + texcoord_offset + 1
                "#{v_idx}/#{texcoord_idx}"

              normal_offset > 0 ->
                # Has normals only
                normal_idx = v_idx
                "#{v_idx}//#{normal_idx}"

              true ->
                # Vertex only
                "#{v_idx}"
            end
          end)
          |> Enum.join(" ")

        face_str = "f #{face_line}"

        # Add material group if material changed
        {updated_lines, new_material} =
          cond do
            material_id == nil ->
              # No material, just add face
              {[face_str | acc], current_material}

            material_id == current_material ->
              # Material hasn't changed, just add face
              {[face_str | acc], current_material}

            true ->
              # Material changed, add usemtl command
              material_name = "material_#{material_id}"
              {["usemtl #{material_name}", face_str | acc], material_id}
          end

        {updated_lines, new_material}
      end)

    Enum.reverse(face_lines)
  end

  # Generate quad faces from indices
  defp generate_quad_faces(indices, vertex_offset, normal_offset, texcoord_offset,
         material_ids) do
    quads = Enum.chunk_every(indices, 4)

    {face_lines, _} =
      quads
      |> Enum.with_index()
      |> Enum.reduce({[], nil}, fn {quad, quad_index}, {acc, current_material} ->
        # Get material for this quad (if material_ids provided)
        material_id =
          if material_ids && length(material_ids) > 0 do
            Enum.at(material_ids, quad_index)
          else
            nil
          end

        # Convert quad indices to OBJ format (1-based)
        face_line =
          quad
          |> Enum.map(fn vertex_idx ->
            # OBJ uses 1-based indexing
            v_idx = vertex_idx + vertex_offset + 1

            # Build face vertex reference: v/vt/vn, v/vt, or v
            cond do
              normal_offset > 0 && texcoord_offset > 0 ->
                # Has both normals and texture coordinates
                normal_idx = v_idx
                texcoord_idx = vertex_idx + texcoord_offset + 1
                "#{v_idx}/#{texcoord_idx}/#{normal_idx}"

              texcoord_offset > 0 ->
                # Has texture coordinates only
                texcoord_idx = vertex_idx + texcoord_offset + 1
                "#{v_idx}/#{texcoord_idx}"

              normal_offset > 0 ->
                # Has normals only
                normal_idx = v_idx
                "#{v_idx}//#{normal_idx}"

              true ->
                # Vertex only
                "#{v_idx}"
            end
          end)
          |> Enum.join(" ")

        face_str = "f #{face_line}"

        # Add material group if material changed
        {updated_lines, new_material} =
          cond do
            material_id == nil ->
              # No material, just add face
              {[face_str | acc], current_material}

            material_id == current_material ->
              # Material hasn't changed, just add face
              {[face_str | acc], current_material}

            true ->
              # Material changed, add usemtl command
              material_name = "material_#{material_id}"
              {["usemtl #{material_name}", face_str | acc], material_id}
          end

        {updated_lines, new_material}
      end)

    Enum.reverse(face_lines)
  end

  defp generate_mtl_content_gltf(document, _base_path) when is_map(document) do
    materials = Map.get(document, :materials) || Map.get(document, "materials") || []
    materials_list = if is_list(materials), do: materials, else: []

    mtl_lines = [
      "# MTL file exported from glTF",
      "# Generated by AriaGltf"
    ]

    mtl_lines =
      materials_list
      |> Enum.with_index()
      |> Enum.reduce(mtl_lines, fn {material, index}, acc ->
        name = Map.get(material, :name) || Map.get(material, "name") || "material_#{index}"
        acc = acc ++ ["", "newmtl #{name}"]

        # Extract PBR metallic roughness properties
        pbr = Map.get(material, :pbr_metallic_roughness) || Map.get(material, "pbrMetallicRoughness")
        acc =
          if pbr do
            # Extract base color factor (diffuse)
            base_color = Map.get(pbr, :base_color_factor) || Map.get(pbr, "baseColorFactor")
            acc =
              if base_color do
                [r, g, b, _a] = base_color
                acc ++ ["Kd #{r} #{g} #{b}"]
              else
                acc
              end

            # Extract metallic factor (for specular approximation)
            # Convert metallic to specular approximation
            metallic = Map.get(pbr, :metallic_factor) || Map.get(pbr, "metallicFactor")
            acc =
              if metallic do
                # Approximate specular from metallic
                specular = metallic * 0.8
                acc ++ ["Ks #{specular} #{specular} #{specular}"]
              else
                acc
              end

            acc
          else
            acc
          end

        # Extract emissive factor
        emissive = Map.get(material, :emissive_factor) || Map.get(material, "emissiveFactor")
        acc =
          if emissive do
            [r, g, b] = emissive
            acc ++ ["Ke #{r} #{g} #{b}"]
          else
            acc
          end

        acc
      end)

    {:ok, Enum.join(mtl_lines, "\n") <> "\n"}
  end

  defp generate_mtl_content_gltf(%AriaGltf.Document{} = document, _base_path) do
    materials = document.materials || []

    mtl_lines = [
      "# MTL file exported from glTF",
      "# Generated by AriaGltf"
    ]

    mtl_lines =
      materials
      |> Enum.with_index()
      |> Enum.reduce(mtl_lines, fn {material, index}, acc ->
        name = material.name || "material_#{index}"
        acc = acc ++ ["", "newmtl #{name}"]

        # Extract PBR metallic roughness properties
        acc =
          if material.pbr_metallic_roughness do
            pbr = material.pbr_metallic_roughness

            # Extract base color factor (diffuse)
            acc =
              if pbr.base_color_factor do
                [r, g, b, _a] = pbr.base_color_factor
                acc ++ ["Kd #{r} #{g} #{b}"]
              else
                acc
              end

            # Extract metallic factor (for specular approximation)
            # Convert metallic to specular approximation
            acc =
              if pbr.metallic_factor do
                metallic = pbr.metallic_factor
                # Approximate specular from metallic
                specular = metallic * 0.8
                acc ++ ["Ks #{specular} #{specular} #{specular}"]
              else
                acc
              end

            acc
          else
            acc
          end

        # Extract emissive factor
        acc =
          if material.emissive_factor do
            [r, g, b] = material.emissive_factor
            acc ++ ["Ke #{r} #{g} #{b}"]
          else
            acc
          end

        acc
      end)

    {:ok, Enum.join(mtl_lines, "\n") <> "\n"}
  end

  defp generate_mtl_content_fbx(%FBXDocument{} = document, _base_path) do
    materials = document.materials || []

    mtl_lines = [
      "# MTL file exported from FBX",
      "# Generated by AriaFbx"
    ]

    mtl_lines =
      Enum.reduce(materials, mtl_lines, fn material, acc ->
        name = material.name || "material_#{material.id}"
        acc = acc ++ ["", "newmtl #{name}"]

        # Add diffuse color
        acc =
          if material.diffuse_color do
            {r, g, b} = material.diffuse_color
            acc ++ ["Kd #{r} #{g} #{b}"]
          else
            acc
          end

        # Add specular color
        acc =
          if material.specular_color do
            {r, g, b} = material.specular_color
            acc ++ ["Ks #{r} #{g} #{b}"]
          else
            acc
          end

        # Add emissive color
        acc =
          if material.emissive_color do
            {r, g, b} = material.emissive_color
            acc ++ ["Ke #{r} #{g} #{b}"]
          else
            acc
          end

        acc
      end)

    {:ok, Enum.join(mtl_lines, "\n") <> "\n"}
  end

  # Unused helper functions - kept for potential future use
  # Removed unused helper functions - they were causing warnings

  # Helper functions for scene/node traversal

  # Get default scene from document
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - Default scene selection logic (document.scene vs first scene)
  # - Fallback behavior
  @doc false
  defp get_default_scene(document) when is_map(document) do
    scenes = Map.get(document, :scenes) || Map.get(document, "scenes") || []
    scene_index = Map.get(document, :scene) || Map.get(document, "scene")

    case scene_index do
      nil ->
        # No default scene specified, use first scene if available
        List.first(scenes)

      index when is_integer(index) ->
        # Get scene at specified index
        scenes_list = if is_list(scenes), do: scenes, else: []
        Enum.at(scenes_list, index)

      _ ->
        # Invalid scene index, use first scene
        List.first(scenes)
    end
  end

  defp get_default_scene(%AriaGltf.Document{} = document) do
    scenes = document.scenes || []

    case document.scene do
      nil ->
        # No default scene specified, use first scene if available
        List.first(scenes)

      scene_index when is_integer(scene_index) ->
        # Get scene at specified index
        Enum.at(scenes, scene_index)

      _ ->
        # Invalid scene index, use first scene
        List.first(scenes)
    end
  end

  # Get root node indices from scene
  @doc false
  defp get_scene_nodes(scene) when is_map(scene) do
    Map.get(scene, :nodes) || Map.get(scene, "nodes") || []
  end

  defp get_scene_nodes(%AriaGltf.Scene{} = scene) do
    scene.nodes || []
  end

  # Get material name from document and material index
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - Material name resolution (name vs fallback)
  # - Nil material handling
  @doc false
  defp get_material_name(document, nil) when is_map(document), do: nil

  defp get_material_name(document, material_index) when is_map(document) and is_integer(material_index) do
    materials = Map.get(document, :materials) || Map.get(document, "materials") || []
    materials_list = if is_list(materials), do: materials, else: []

    case Enum.at(materials_list, material_index) do
      nil ->
        "material_#{material_index}"

      material when is_map(material) ->
        name = Map.get(material, :name) || Map.get(material, "name")
        name || "material_#{material_index}"

      %AriaGltf.Material{name: name} ->
        name || "material_#{material_index}"
    end
  end

  defp get_material_name(%AriaGltf.Document{} = _document, nil), do: nil

  defp get_material_name(%AriaGltf.Document{} = document, material_index)
       when is_integer(material_index) do
    materials = document.materials || []

    case Enum.at(materials, material_index) do
      nil ->
        "material_#{material_index}"

      %AriaGltf.Material{name: name} ->
        name || "material_#{material_index}"
    end
  end

  # Build node path by appending node name
  # TODO: 2025-11-03 fire - Add ExDoc documentation explaining:
  # - Node path construction for object groups
  # - Name fallback (node_#{index} when name is nil)
  # - Path concatenation format
  @doc false
  defp build_node_path(node_path, node_index, node_name) do
    path_name =
      cond do
        node_name && String.trim(node_name) != "" -> node_name
        true -> "node_#{node_index}"
      end

    node_path ++ [path_name]
  end
end

