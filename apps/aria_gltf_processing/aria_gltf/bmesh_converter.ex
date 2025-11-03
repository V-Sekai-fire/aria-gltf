# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.BmeshConverter do
  @moduledoc """
  Converts glTF meshes to BMesh format.

  This module handles conversion from glTF triangle meshes to BMesh, supporting:
  - Direct import from VSEKAI_mesh_bmesh extension (preserves topology)
  - Reconstruction from triangle meshes (triangle fan algorithm)
  - Export to VSEKAI_mesh_bmesh extension or triangle encoding
  """

  alias AriaBmesh.Mesh, as: Bmesh
  alias AriaGltf.{Document, Mesh.Primitive, BufferView, Accessor}
  alias AriaGltf.Extensions.VsekaiMeshBmesh.{Import, TriangleReconstruction, TriangleEncoding, Export}
  alias AriaGltf.Import.BinaryLoader
  alias AriaGltf.Helpers.BufferManagement

  @vsekai_extension_name "VSEKAI_mesh_bmesh"

  @doc """
  Converts a glTF document's meshes to BMesh format.

  For each primitive:
  - If VSEKAI_mesh_bmesh extension is present, use direct import
  - Otherwise, reconstruct BMesh from triangles

  ## Parameters
  - `document`: The glTF document to convert

  ## Returns
  - `{:ok, bmeshes}` - List of BMesh structures (one per mesh)
  - `{:error, reason}` - Error during conversion

  ## Examples

      iex> {:ok, document} = AriaGltf.Import.from_file("model.gltf")
      iex> AriaGltf.BmeshConverter.from_gltf_document(document)
      {:ok, [%AriaBmesh.Mesh{}, ...]}
  """
  @spec from_gltf_document(Document.t()) :: {:ok, [Bmesh.t()]} | {:error, String.t()}
  def from_gltf_document(%Document{} = document) do
    meshes = document.meshes || []

    bmeshes =
      Enum.reduce(meshes, [], fn mesh, acc ->
        case convert_mesh_to_bmesh(document, mesh) do
          {:ok, bmesh} -> [bmesh | acc]
          {:error, _reason} -> acc
        end
      end)

    {:ok, Enum.reverse(bmeshes)}
  end

  # Convert a single glTF mesh to BMesh
  defp convert_mesh_to_bmesh(%Document{} = document, %AriaGltf.Mesh{} = mesh) do
    primitives = mesh.primitives || []

    # Convert each primitive and combine into a single BMesh
    Enum.reduce(primitives, {:ok, Bmesh.new()}, fn primitive, acc ->
      case acc do
        {:ok, combined_bmesh} ->
          case convert_primitive_to_bmesh(document, primitive) do
            {:ok, primitive_bmesh} ->
              {:ok, merge_bmeshes(combined_bmesh, primitive_bmesh)}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, _} = error ->
          error
      end
    end)
  end

  @doc """
  Converts a single glTF primitive to BMesh format.

  For each primitive:
  - If VSEKAI_mesh_bmesh extension is present, use direct import
  - Otherwise, reconstruct BMesh from triangles

  ## Parameters
  - `document`: The glTF document
  - `primitive`: The primitive to convert

  ## Returns
  - `{:ok, bmesh}` - BMesh structure
  - `{:error, reason}` - Error during conversion

  ## Examples

      iex> primitive = %AriaGltf.Mesh.Primitive{attributes: %{"POSITION" => 0}}
      iex> AriaGltf.BmeshConverter.convert_primitive_to_bmesh(document, primitive)
      {:ok, %AriaBmesh.Mesh{}}

  ## ExDoc Improvements

  TODO: 2025-11-03 fire - Add more detailed examples showing:
  - Extension-based import workflow
  - Triangle reconstruction workflow
  - Error scenarios and recovery
  - Integration with OBJ export pipeline
  """
  @spec convert_primitive_to_bmesh(Document.t(), Primitive.t()) ::
          {:ok, Bmesh.t()} | {:error, String.t()}
  def convert_primitive_to_bmesh(%Document{} = document, %Primitive{} = primitive) do
    # Check for VSEKAI_mesh_bmesh extension
    extensions = primitive.extensions || %{}

    case Map.get(extensions, @vsekai_extension_name) do
      nil ->
        # No extension, reconstruct from triangles
        reconstruct_from_triangles(document, primitive)

      ext_bmesh when is_map(ext_bmesh) ->
        # Direct import from VSEKAI_mesh_bmesh
        Import.from_gltf(document, primitive, ext_bmesh)
    end
  end

  # Reconstruct BMesh from triangle mesh
  defp reconstruct_from_triangles(%Document{} = document, %Primitive{} = primitive) do
    # Extract positions and indices from accessors
    with {:ok, positions} <- extract_positions(document, primitive),
         {:ok, indices} <- extract_indices(document, primitive) do
      # Handle auto indices (sequential 0, 1, 2, ...)
      final_indices =
        case indices do
          :auto_indices ->
            length = length(positions)
            0..(length - 1) |> Enum.to_list()

          indices_list ->
            indices_list
        end

      TriangleReconstruction.from_triangles(document, primitive, positions, final_indices)
    end
  end

  # Extract vertex positions from primitive accessors
  defp extract_positions(%Document{} = document, %Primitive{} = primitive) do
    case Map.get(primitive.attributes, "POSITION") do
      nil ->
        {:error, "Primitive missing POSITION attribute"}

      position_accessor_idx ->
        accessors = document.accessors || []

        case Enum.at(accessors, position_accessor_idx) do
          nil ->
            {:error, "Invalid POSITION accessor index: #{position_accessor_idx}"}

          accessor ->
            extract_vec3_accessor(document, accessor)
        end
    end
  end

  # Extract triangle indices from primitive
  defp extract_indices(%Document{} = document, %Primitive{} = primitive) do
    case primitive.indices do
      nil ->
        # Generate sequential indices (0, 1, 2, 3, ...)
        {:ok, :auto_indices}

      index_accessor_idx ->
        accessors = document.accessors || []

        case Enum.at(accessors, index_accessor_idx) do
          nil ->
            {:error, "Invalid indices accessor index: #{index_accessor_idx}"}

          accessor ->
            extract_indices_accessor(document, accessor)
        end
    end
  end

  # Extract Vec3 positions from accessor
  defp extract_vec3_accessor(%Document{} = document, %AriaGltf.Accessor{} = accessor) do
    with {:ok, raw_data} <- read_accessor_data(document, accessor),
         {:ok, positions} <- decode_vec3_accessor(raw_data, accessor) do
      {:ok, positions}
    end
  end

  # Extract indices from accessor
  defp extract_indices_accessor(%Document{} = document, %AriaGltf.Accessor{} = accessor) do
    with {:ok, raw_data} <- read_accessor_data(document, accessor),
         indices <- decode_indices_accessor(raw_data, accessor) do
      {:ok, indices}
    end
  end

  # Read accessor data from buffer view
  defp read_accessor_data(%Document{} = document, %AriaGltf.Accessor{} = accessor) do
    case accessor.buffer_view do
      nil ->
        {:error, "Accessor missing buffer_view"}

      bv_index ->
        buffer_views = document.buffer_views || []
        buffers = document.buffers || []

        case Enum.at(buffer_views, bv_index) do
          nil ->
            {:error, "Invalid buffer view index: #{bv_index}"}

          buffer_view ->
            buffer_index = buffer_view.buffer

            case Enum.at(buffers, buffer_index) do
              nil ->
                {:error, "Invalid buffer index: #{buffer_index}"}

              %AriaGltf.Buffer{data: nil} ->
                {:error, "Buffer #{buffer_index} has no data"}

              %AriaGltf.Buffer{data: buffer_data} ->
                buffer_offset = buffer_view.byte_offset || 0
                accessor_offset = accessor.byte_offset || 0
                total_offset = buffer_offset + accessor_offset

                element_size = AriaGltf.Accessor.element_byte_size(accessor)
                total_length = accessor.count * element_size

                if byte_size(buffer_data) >= total_offset + total_length do
                  <<_::binary-size(total_offset), data::binary-size(total_length), _::binary>> =
                    buffer_data

                  {:ok, data}
                else
                  {:error, "Accessor data extends beyond buffer"}
                end
            end
        end
    end
  end

  # Decode Vec3 accessor data to list of {x, y, z} tuples
  defp decode_vec3_accessor(data, %AriaGltf.Accessor{} = accessor) do
    component_size = AriaGltf.Accessor.component_byte_size(accessor.component_type)
    element_size = component_size * 3
    normalized? = accessor.normalized || false

    try do
      positions =
        0..(accessor.count - 1)
        |> Enum.map(fn i ->
          offset = i * element_size
          decode_vec3_element(data, offset, accessor.component_type, normalized?)
        end)

      {:ok, positions}
    rescue
      error -> {:error, "Failed to decode Vec3 accessor: #{inspect(error)}"}
    end
  end

  # Decode a single Vec3 element
  defp decode_vec3_element(data, offset, 5126, _normalized?) do
    # FLOAT (4 bytes per component) - always in float range, no normalization needed
    <<_::binary-size(offset), x::little-float-32, y::little-float-32, z::little-float-32,
      _::binary>> = data
    {x, y, z}
  end

  defp decode_vec3_element(data, offset, component_type, normalized?) do
    # Support other component types (normalized and non-normalized)
    case {component_type, normalized?} do
      {5120, true} ->
        # BYTE (signed 8-bit) normalized to [-1, 1]
        <<_::binary-size(offset), x::little-signed-8, y::little-signed-8, z::little-signed-8,
          _::binary>> = data
        {x / 127.0, y / 127.0, z / 127.0}

      {5120, false} ->
        # BYTE (signed 8-bit) non-normalized - use as-is for positions
        <<_::binary-size(offset), x::little-signed-8, y::little-signed-8, z::little-signed-8,
          _::binary>> = data
        {x / 1.0, y / 1.0, z / 1.0}

      {5121, true} ->
        # UNSIGNED_BYTE (unsigned 8-bit) normalized to [0, 1]
        <<_::binary-size(offset), x::little-unsigned-8, y::little-unsigned-8,
          z::little-unsigned-8, _::binary>> = data
        {x / 255.0, y / 255.0, z / 255.0}

      {5121, false} ->
        # UNSIGNED_BYTE (unsigned 8-bit) non-normalized - use as-is
        <<_::binary-size(offset), x::little-unsigned-8, y::little-unsigned-8,
          z::little-unsigned-8, _::binary>> = data
        {x / 1.0, y / 1.0, z / 1.0}

      {5122, true} ->
        # SHORT (signed 16-bit) normalized to [-1, 1]
        <<_::binary-size(offset), x::little-signed-16, y::little-signed-16,
          z::little-signed-16, _::binary>> = data
        {x / 32767.0, y / 32767.0, z / 32767.0}

      {5122, false} ->
        # SHORT (signed 16-bit) non-normalized - use as-is for positions
        <<_::binary-size(offset), x::little-signed-16, y::little-signed-16,
          z::little-signed-16, _::binary>> = data
        {x / 1.0, y / 1.0, z / 1.0}

      {5123, true} ->
        # UNSIGNED_SHORT (unsigned 16-bit) normalized to [0, 1]
        <<_::binary-size(offset), x::little-unsigned-16, y::little-unsigned-16,
          z::little-unsigned-16, _::binary>> = data
        {x / 65535.0, y / 65535.0, z / 65535.0}

      {5123, false} ->
        # UNSIGNED_SHORT (unsigned 16-bit) non-normalized - use as-is for positions
        <<_::binary-size(offset), x::little-unsigned-16, y::little-unsigned-16,
          z::little-unsigned-16, _::binary>> = data
        {x / 1.0, y / 1.0, z / 1.0}

      {5125, true} ->
        # UNSIGNED_INT normalized is not allowed per spec (normalized must not be true for UNSIGNED_INT)
        raise "UNSIGNED_INT cannot be normalized per glTF spec"

      {5125, false} ->
        # UNSIGNED_INT (unsigned 32-bit) non-normalized - use as-is for positions
        <<_::binary-size(offset), x::little-unsigned-32, y::little-unsigned-32,
          z::little-unsigned-32, _::binary>> = data
        {x / 1.0, y / 1.0, z / 1.0}

      _ ->
        raise "Unsupported component type for positions: #{component_type}"
    end
  end

  # Decode indices accessor data to list of integers
  defp decode_indices_accessor(data, %AriaGltf.Accessor{} = accessor) do
    component_size = AriaGltf.Accessor.component_byte_size(accessor.component_type)

    0..(accessor.count - 1)
    |> Enum.map(fn i ->
      offset = i * component_size
      decode_index_element(data, offset, accessor.component_type)
    end)
  end

  # Decode a single index element
  defp decode_index_element(data, offset, 5123) do
    # UNSIGNED_SHORT (2 bytes)
    <<_::binary-size(offset), index::little-unsigned-16, _::binary>> = data
    index
  end

  defp decode_index_element(data, offset, 5125) do
    # UNSIGNED_INT (4 bytes)
    <<_::binary-size(offset), index::little-unsigned-32, _::binary>> = data
    index
  end

  defp decode_index_element(_data, _offset, component_type) do
    raise "Unsupported component type for indices: #{component_type}"
  end

  # Merge two BMeshes (combines all vertices, edges, loops, faces)
  defp merge_bmeshes(%Bmesh{} = bmesh1, %Bmesh{} = bmesh2) do
    # Calculate offsets from bmesh1 counts
    vertex_offset = map_size(bmesh1.vertices)
    edge_offset = map_size(bmesh1.edges)
    loop_offset = map_size(bmesh1.loops)
    face_offset = map_size(bmesh1.faces)

    # Merge vertices with ID remapping
    {merged_vertices, vertex_id_map} =
      merge_vertices(bmesh1.vertices, bmesh2.vertices, vertex_offset)

    # Merge edges with ID remapping and vertex reference updates
    {merged_edges, edge_id_map} =
      merge_edges(bmesh1.edges, bmesh2.edges, edge_offset, vertex_id_map)

    # Merge faces with ID remapping and vertex reference updates
    {merged_faces, face_id_map} =
      merge_faces(bmesh1.faces, bmesh2.faces, face_offset, vertex_id_map, edge_id_map)

    # Merge loops with ID remapping and full reference updates
    {merged_loops, loop_id_map} =
      merge_loops(
        bmesh1.loops,
        bmesh2.loops,
        loop_offset,
        vertex_id_map,
        edge_id_map,
        face_id_map
      )

    # Update vertex edge connections
    updated_vertices = update_vertex_edge_references(merged_vertices, edge_id_map)

    # Update face loop references
    updated_faces = update_face_loop_references(merged_faces, loop_id_map)

    # Create merged mesh
    %Bmesh{
      vertices: updated_vertices,
      edges: merged_edges,
      loops: merged_loops,
      faces: updated_faces,
      next_vertex_id: bmesh1.next_vertex_id + map_size(bmesh2.vertices),
      next_edge_id: bmesh1.next_edge_id + map_size(bmesh2.edges),
      next_loop_id: bmesh1.next_loop_id + map_size(bmesh2.loops),
      next_face_id: bmesh1.next_face_id + map_size(bmesh2.faces)
    }
  end

  # Merge vertex maps with ID remapping
  defp merge_vertices(vertices1, vertices2, offset) do
    {merged, id_map} =
      Enum.reduce(vertices2, {vertices1, %{}}, fn {old_id, vertex}, {acc, map} ->
        new_id = old_id + offset
        updated_vertex = %{vertex | id: new_id}
        {Map.put(acc, new_id, updated_vertex), Map.put(map, old_id, new_id)}
      end)

    {merged, id_map}
  end

  # Merge edge maps with ID remapping and vertex reference updates
  defp merge_edges(edges1, edges2, offset, vertex_id_map) do
    {merged, id_map} =
      Enum.reduce(edges2, {edges1, %{}}, fn {old_id, edge}, {acc, map} ->
        new_id = old_id + offset
        # Remap vertex references
        {v1, v2} = edge.vertices
        new_vertices = {
          Map.get(vertex_id_map, v1, v1),
          Map.get(vertex_id_map, v2, v2)
        }

        updated_edge = %{edge | id: new_id, vertices: new_vertices}
        {Map.put(acc, new_id, updated_edge), Map.put(map, old_id, new_id)}
      end)

    {merged, id_map}
  end

  # Merge face maps with ID remapping and vertex/edge reference updates
  defp merge_faces(faces1, faces2, offset, vertex_id_map, edge_id_map) do
    {merged, id_map} =
      Enum.reduce(faces2, {faces1, %{}}, fn {old_id, face}, {acc, map} ->
        new_id = old_id + offset

        # Remap vertex references
        remapped_vertices = Enum.map(face.vertices, fn v -> Map.get(vertex_id_map, v, v) end)

        # Remap edge references
        remapped_edges = Enum.map(face.edges, fn e -> Map.get(edge_id_map, e, e) end)

        # Remap loop references (will be done in merge_loops)
        updated_face = %{
          face
          | id: new_id,
            vertices: remapped_vertices,
            edges: remapped_edges
        }

        {Map.put(acc, new_id, updated_face), Map.put(map, old_id, new_id)}
      end)

    {merged, id_map}
  end

  # Merge loop maps with full reference updates
  defp merge_loops(loops1, loops2, offset, vertex_id_map, edge_id_map, face_id_map) do
    {merged, id_map} =
      Enum.reduce(loops2, {loops1, %{}}, fn {old_id, loop}, {acc, map} ->
        new_id = old_id + offset

        # Remap all references
        remapped_vertex = Map.get(vertex_id_map, loop.vertex, loop.vertex)
        remapped_edge = Map.get(edge_id_map, loop.edge, loop.edge)
        remapped_face = Map.get(face_id_map, loop.face, loop.face)

        # Remap next/prev pointers (these point to loops in bmesh2, so need offset)
        remapped_next = if loop.next, do: Map.get(map, loop.next, loop.next) + offset, else: nil
        remapped_prev = if loop.prev, do: Map.get(map, loop.prev, loop.prev) + offset, else: nil

        # Remap radial pointers (these point to loops in bmesh2, so need offset)
        remapped_radial_next =
          if loop.radial_next do
            Map.get(map, loop.radial_next, loop.radial_next) + offset
          else
            nil
          end

        remapped_radial_prev =
          if loop.radial_prev do
            Map.get(map, loop.radial_prev, loop.radial_prev) + offset
          else
            nil
          end

        updated_loop = %{
          loop
          | id: new_id,
            vertex: remapped_vertex,
            edge: remapped_edge,
            face: remapped_face,
            next: remapped_next,
            prev: remapped_prev,
            radial_next: remapped_radial_next,
            radial_prev: remapped_radial_prev
        }

        {Map.put(acc, new_id, updated_loop), Map.put(map, old_id, new_id)}
      end)

    {merged, id_map}
  end

  # Update vertex edge references after edge ID remapping
  defp update_vertex_edge_references(vertices, edge_id_map) do
    Enum.reduce(vertices, vertices, fn {vertex_id, vertex}, acc ->
      remapped_edges =
        Enum.map(vertex.edges, fn edge_id -> Map.get(edge_id_map, edge_id, edge_id) end)

      updated_vertex = %{vertex | edges: remapped_edges}
      Map.put(acc, vertex_id, updated_vertex)
    end)
  end

  # Update face loop references after loop ID remapping
  defp update_face_loop_references(faces, loop_id_map) do
    Enum.reduce(faces, faces, fn {face_id, face}, acc ->
      remapped_loops =
        Enum.map(face.loops, fn loop_id -> Map.get(loop_id_map, loop_id, loop_id) end)

      updated_face = %{face | loops: remapped_loops}
      Map.put(acc, face_id, updated_face)
    end)
  end

  @doc """
  Converts BMesh to glTF document format.

  ## Parameters
  - `bmesh`: The BMesh to convert
  - `opts`: Options:
    - `:use_extension` - Use VSEKAI_mesh_bmesh extension (default: false, exports as triangles)
    - `:include_normals` - Include face normals (default: true)

  ## Returns
  - `{:ok, mesh_primitive}` - glTF Mesh.Primitive structure
  - `{:error, reason}` - Error during conversion

  ## Examples

      iex> bmesh = AriaBmesh.Mesh.new()
      iex> # ... populate bmesh ...
      iex> AriaGltf.BmeshConverter.to_gltf_primitive(bmesh)
      {:ok, %AriaGltf.Mesh.Primitive{}}
  """
  @spec to_gltf_primitive(Bmesh.t(), keyword()) ::
          {:ok, Primitive.t(), [BufferView.t()], [Accessor.t()], binary()} | {:error, String.t()}
  def to_gltf_primitive(%Bmesh{} = bmesh, opts \\ []) do
    use_extension = Keyword.get(opts, :use_extension, false)

    if use_extension do
      # Export as VSEKAI_mesh_bmesh extension
      export_with_extension(bmesh, opts)
    else
      # Export as triangles (backward compatible)
      export_as_triangles(bmesh, opts)
    end
  end

  # Export BMesh using VSEKAI_mesh_bmesh extension
  defp export_with_extension(%Bmesh{} = bmesh, opts) do
    with {:ok, extension_json, buffer_data} <- Export.to_gltf(bmesh, %{}, opts),
         extension_map <- %{@vsekai_extension_name => extension_json} do
      # Create primitive with extension
      primitive = %Primitive{
        attributes: %{"POSITION" => 0},
        extensions: extension_map,
        mode: 4
      }

      # For extension export, return empty buffer views/accessors (handled by extension)
      {:ok, primitive, [], [], buffer_data}
    end
  end

  # Export BMesh as triangles (triangle fan encoding)
  defp export_as_triangles(%Bmesh{} = bmesh, _opts) do
    with {:ok, {positions, indices}} <- TriangleEncoding.to_triangle_mesh(bmesh) do
      # Encode positions as Vec3<f32> binary (12 bytes per position)
      positions_binary =
        positions
        |> Enum.map(fn {x, y, z} ->
          <<x::little-float-32, y::little-float-32, z::little-float-32>>
        end)
        |> Enum.reduce(<<>>, fn bin, acc -> acc <> bin end)

      positions_count = length(positions)
      positions_byte_length = positions_count * 12

      # Determine index component type (u16 or u32)
      max_index = if length(indices) > 0, do: Enum.max(indices), else: 0
      {index_component_type, index_component_size} =
        if max_index < 65535 do
          {5123, 2} # UNSIGNED_SHORT
        else
          {5125, 4} # UNSIGNED_INT
        end

      # Encode indices as binary
      indices_binary =
        indices
        |> Enum.map(fn index ->
          if index_component_size == 2 do
            <<index::little-unsigned-16>>
          else
            <<index::little-unsigned-32>>
          end
        end)
        |> Enum.reduce(<<>>, fn bin, acc -> acc <> bin end)

      indices_count = length(indices)
      indices_byte_length = indices_count * index_component_size

      # Calculate buffer offsets
      positions_offset = 0
      indices_offset = positions_byte_length

      # Create buffer views
      positions_buffer_view =
        BufferManagement.create_buffer_view(
          buffer: 0,
          byte_offset: positions_offset,
          byte_length: positions_byte_length,
          target: 34_962,
          name: "Positions"
        )

      indices_buffer_view =
        BufferManagement.create_buffer_view(
          buffer: 0,
          byte_offset: indices_offset,
          byte_length: indices_byte_length,
          target: 34_963,
          name: "Indices"
        )

      # Calculate min/max for positions
      {min_pos, max_pos} = calculate_positions_bounds(positions)

      # Create accessors
      position_accessor =
        BufferManagement.create_accessor(
          buffer_view: 0,
          component_type: 5126,
          count: positions_count,
          type: "VEC3",
          byte_offset: 0,
          min: min_pos,
          max: max_pos,
          name: "Positions"
        )

      index_accessor =
        BufferManagement.create_accessor(
          buffer_view: 1,
          component_type: index_component_type,
          count: indices_count,
          type: "SCALAR",
          byte_offset: 0,
          name: "Indices"
        )

      # Create primitive with accessor references
      primitive = %Primitive{
        attributes: %{"POSITION" => 0},
        indices: 1,
        mode: 4
      }

      # Return primitive, buffer views, accessors, and binary data
      {:ok, primitive, [positions_buffer_view, indices_buffer_view], [position_accessor, index_accessor],
       positions_binary <> indices_binary}
    end
  end

  # Calculate min/max bounds for positions
  defp calculate_positions_bounds(positions) when is_list(positions) and length(positions) > 0 do
    {min_x, min_y, min_z, max_x, max_y, max_z} =
      Enum.reduce(positions, {nil, nil, nil, nil, nil, nil}, fn {x, y, z},
                                                                 {min_x, min_y, min_z, max_x,
                                                                  max_y, max_z} ->
        {
          if(is_nil(min_x), do: x, else: min(min_x, x)),
          if(is_nil(min_y), do: y, else: min(min_y, y)),
          if(is_nil(min_z), do: z, else: min(min_z, z)),
          if(is_nil(max_x), do: x, else: max(max_x, x)),
          if(is_nil(max_y), do: y, else: max(max_y, y)),
          if(is_nil(max_z), do: z, else: max(max_z, z))
        }
      end)

    {[min_x, min_y, min_z], [max_x, max_y, max_z]}
  end

  defp calculate_positions_bounds(_), do: {nil, nil}
end

