# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaDocument.Import.Obj do
  @moduledoc """
  Wavefront OBJ format importer.

  Parses OBJ files and converts them to structured document format.
  Supports vertices, normals, texture coordinates, faces, materials, and groups.

  ## Features

  - Handles all OBJ face formats: `v`, `v/vt`, `v//vn`, `v/vt/vn`
  - Parses MTL material files
  - Supports object groups (`g` commands) and object names (`o` commands)
  - Converts 1-based OBJ indexing to 0-based internal indexing
  - Preserves material assignments (`usemtl` commands)
  """

  alias AriaObj.Document

  @doc """
  Imports an OBJ file from disk.

  ## Options

  - `:load_mtl` - Whether to automatically load MTL files referenced by `mtllib` (default: `true`)
  - `:base_path` - Base directory for resolving relative MTL paths (default: directory of obj_path)

  ## Examples

      {:ok, document} = AriaDocument.Import.Obj.from_file("/path/to/model.obj")
      {:error, reason} = AriaDocument.Import.Obj.from_file("/path/to/invalid.obj")
  """
  @spec from_file(String.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def from_file(file_path, opts \\ []) when is_binary(file_path) do
    with {:ok, content} <- File.read(file_path) do
      base_path = Keyword.get(opts, :base_path, Path.dirname(file_path))
      load_mtl? = Keyword.get(opts, :load_mtl, true)
      opts = Keyword.put(opts, :base_path, base_path) |> Keyword.put(:load_mtl, load_mtl?)

      from_string(content, opts)
    else
      error -> error
    end
  end

  @doc """
  Imports an OBJ document from string content.

  ## Options

  - `:load_mtl` - Whether to automatically load MTL files referenced by `mtllib` (default: `true`)
  - `:base_path` - Base directory for resolving relative MTL paths (default: current directory)

  ## Examples

      {:ok, document} = AriaDocument.Import.Obj.from_string(obj_content)
  """
  @spec from_string(String.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def from_string(content, opts \\ []) when is_binary(content) do
    base_path = Keyword.get(opts, :base_path, ".")
    load_mtl? = Keyword.get(opts, :load_mtl, true)

    lines = String.split(content, "\n")
    document = parse_geometry(lines, base_path, load_mtl?)

    {:ok, document}
  end

  @doc """
  Parses OBJ geometry from lines.

  Returns a structured document with vertices, normals, texture coordinates, faces, materials, and groups.
  """
  @spec parse_geometry([String.t()], String.t(), boolean()) :: Document.t()
  def parse_geometry(lines, base_path \\ ".", load_mtl? \\ true) do
    initial_state = Document.new(
      mtl_materials: nil
    )

    %Document{} = state =
      Enum.reduce(lines, initial_state, fn line, acc ->
        parse_line(line, acc, base_path, load_mtl?)
      end)

    # Reverse lists to maintain order (we're prepending)
    %Document{
      state
      | vertices: Enum.reverse(state.vertices),
        normals: Enum.reverse(state.normals),
        texcoords: Enum.reverse(state.texcoords),
        faces: Enum.reverse(state.faces),
        materials: Enum.reverse(state.materials),
        groups: Enum.reverse(state.groups)
    }
  end

  @doc """
  Parses an MTL material file.

  Returns a map of material names to material properties.

  ## Examples

      {:ok, materials} = AriaDocument.Import.Obj.parse_mtl("/path/to/materials.mtl")
      # %{"Material1" => %{diffuse: {1.0, 0.0, 0.0}, ...}, ...}
  """
  @spec parse_mtl(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_mtl(file_path) when is_binary(file_path) do
    with {:ok, content} <- File.read(file_path) do
      parse_mtl_from_string(content)
    else
      error -> error
    end
  end

  @spec parse_mtl_from_string(String.t()) :: {:ok, map()}
  def parse_mtl_from_string(content) when is_binary(content) do
    lines = String.split(content, "\n")
    materials = parse_mtl_lines(lines, %{}, nil)

    {:ok, materials}
  end

  # Parse a single line from OBJ file
  defp parse_line(line, state, base_path, load_mtl?) do
    trimmed = String.trim(line)

    cond do
      # Skip comments and empty lines
      trimmed == "" or String.starts_with?(trimmed, "#") ->
        state

        # Material library: mtllib filename.mtl
      String.starts_with?(trimmed, "mtllib ") ->
        mtl_name = String.slice(trimmed, 7, String.length(trimmed) - 7) |> String.trim()
        mtl_path = Path.join(base_path, mtl_name)
        new_state = %{state | mtllib: mtl_name}

        if load_mtl? and File.exists?(mtl_path) do
          case parse_mtl(mtl_path) do
            {:ok, materials} ->
              # Store material names in materials list
              material_names = Map.keys(materials)
              %{new_state | materials: material_names ++ state.materials, mtl_materials: materials}

            {:error, _} ->
              new_state
          end
        else
          new_state
        end

      # Vertices: v x y z [w]
      String.starts_with?(trimmed, "v ") ->
        case parse_vertex_line(trimmed) do
          {:ok, vertex} -> %{state | vertices: [vertex | state.vertices]}
          :error -> state
        end

      # Normals: vn x y z
      String.starts_with?(trimmed, "vn ") ->
        case parse_normal_line(trimmed) do
          {:ok, normal} -> %{state | normals: [normal | state.normals]}
          :error -> state
        end

      # Texture coordinates: vt u v [w]
      String.starts_with?(trimmed, "vt ") ->
        case parse_texcoord_line(trimmed) do
          {:ok, texcoord} -> %{state | texcoords: [texcoord | state.texcoords]}
          :error -> state
        end

      # Faces: f v1/vt1/vn1 v2/vt2/vn2 ...
      String.starts_with?(trimmed, "f ") ->
        case parse_face_line(trimmed) do
          {:ok, face} -> %{state | faces: [face | state.faces]}
          :error -> state
        end

      # Material: usemtl material_name
      String.starts_with?(trimmed, "usemtl ") ->
        material = String.slice(trimmed, 7, String.length(trimmed) - 7) |> String.trim()
        %{state | current_material: material}

      # Object group: g group_name
      String.starts_with?(trimmed, "g ") ->
        group = String.slice(trimmed, 2, String.length(trimmed) - 2) |> String.trim()
        %{state | current_group: group, groups: [group | state.groups]}

      # Object name: o object_name
      String.starts_with?(trimmed, "o ") ->
        group = String.slice(trimmed, 2, String.length(trimmed) - 2) |> String.trim()
        %{state | current_group: group, groups: [group | state.groups]}

      # Other commands (s, bevel, etc.) - ignore
      true ->
        state
    end
  end

  # Parse vertex line: v x y z [w]
  defp parse_vertex_line("v " <> rest) do
    values = extract_floats(rest)
    cond do
      length(values) == 4 ->
        {:ok, {Enum.at(values, 0), Enum.at(values, 1), Enum.at(values, 2), Enum.at(values, 3)}}

      length(values) == 3 ->
        {:ok, {Enum.at(values, 0), Enum.at(values, 1), Enum.at(values, 2)}}

      true ->
        :error
    end
  end

  defp parse_vertex_line(_), do: :error

  # Parse normal line: vn x y z
  defp parse_normal_line("vn " <> rest) do
    values = extract_floats(rest)
    cond do
      length(values) >= 3 ->
        {:ok, {Enum.at(values, 0), Enum.at(values, 1), Enum.at(values, 2)}}

      true ->
        :error
    end
  end

  defp parse_normal_line(_), do: :error

  # Parse texture coordinate line: vt u v [w]
  defp parse_texcoord_line("vt " <> rest) do
    values = extract_floats(rest)
    cond do
      length(values) >= 3 ->
        {:ok, {Enum.at(values, 0), Enum.at(values, 1), Enum.at(values, 2)}}

      length(values) == 2 ->
        {:ok, {Enum.at(values, 0), Enum.at(values, 1)}}

      true ->
        :error
    end
  end

  defp parse_texcoord_line(_), do: :error

  # Parse face line: f v1/vt1/vn1 v2/vt2/vn2 ...
  defp parse_face_line("f " <> rest) do
    vertices = String.split(rest) |> Enum.map(&parse_face_vertex/1)
    if Enum.all?(vertices, &(!is_nil(&1))) and length(vertices) >= 3 do
      {:ok, vertices}
    else
      :error
    end
  end

  defp parse_face_line(_), do: :error

  # Parse face vertex: v, v/vt, v//vn, or v/vt/vn
  # Returns {v_index, vt_index, vn_index} with 1-based indices
  defp parse_face_vertex(vertex_str) do
    parts = String.split(vertex_str, "/")
    cond do
      length(parts) == 1 ->
        # v only
        case Integer.parse(Enum.at(parts, 0)) do
          {v, _} -> {v, nil, nil}
          :error -> nil
        end

      length(parts) == 2 ->
        # v/vt or v//vn
        case Integer.parse(Enum.at(parts, 0)) do
          {v, _} ->
            vt_str = Enum.at(parts, 1)
            if vt_str == "" do
              # v//vn - need to parse third part
              nil
            else
              case Integer.parse(vt_str) do
                {vt, _} -> {v, vt, nil}
                :error -> nil
              end
            end

          :error ->
            nil
        end

      length(parts) == 3 ->
        # v/vt/vn or v//vn
        v_result = Integer.parse(Enum.at(parts, 0))
        vt_str = Enum.at(parts, 1)
        vn_result = Integer.parse(Enum.at(parts, 2))

        case {v_result, vt_str, vn_result} do
          {{v, _}, "", {vn, _}} ->
            # v//vn format
            {v, nil, vn}

          {{v, _}, vt_str, {vn, _}} when vt_str != "" ->
            # v/vt/vn format
            case Integer.parse(vt_str) do
              {vt, _} -> {v, vt, vn}
              :error -> nil
            end

          _ ->
            nil
        end

      true ->
        nil
    end
  end

  # Extract floating point numbers from string
  defp extract_floats(str) do
    Regex.scan(~r/-?\d+\.?\d*(?:[eE][+-]?\d+)?/, str)
    |> Enum.map(fn [match] ->
      case Float.parse(match) do
        {value, _} -> value
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Parse MTL file lines
  defp parse_mtl_lines(lines, materials, current_material) do
    Enum.reduce(lines, {materials, current_material}, fn line, {mats, current} ->
      trimmed = String.trim(line)

      cond do
        # Skip comments and empty lines
        trimmed == "" or String.starts_with?(trimmed, "#") ->
          {mats, current}

        # New material: newmtl material_name
        String.starts_with?(trimmed, "newmtl ") ->
          material_name = String.slice(trimmed, 7, String.length(trimmed) - 7) |> String.trim()
          new_mat = %{
            diffuse: {0.8, 0.8, 0.8},
            ambient: {0.2, 0.2, 0.2},
            specular: {1.0, 1.0, 1.0},
            shininess: 0.0,
            transparency: 1.0,
            illum: 2
          }
          {Map.put(mats, material_name, new_mat), material_name}

        # Diffuse color: Kd r g b
        String.starts_with?(trimmed, "Kd ") and current != nil ->
          case extract_floats(trimmed) do
            [r, g, b] ->
              updated_mat = Map.update!(mats, current, fn mat ->
                Map.put(mat, :diffuse, {r, g, b})
              end)
              {updated_mat, current}

            _ ->
              {mats, current}
          end

        # Ambient color: Ka r g b
        String.starts_with?(trimmed, "Ka ") and current != nil ->
          case extract_floats(trimmed) do
            [r, g, b] ->
              updated_mat = Map.update!(mats, current, fn mat ->
                Map.put(mat, :ambient, {r, g, b})
              end)
              {updated_mat, current}

            _ ->
              {mats, current}
          end

        # Specular color: Ks r g b
        String.starts_with?(trimmed, "Ks ") and current != nil ->
          case extract_floats(trimmed) do
            [r, g, b] ->
              updated_mat = Map.update!(mats, current, fn mat ->
                Map.put(mat, :specular, {r, g, b})
              end)
              {updated_mat, current}

            _ ->
              {mats, current}
          end

        # Shininess: Ns value
        String.starts_with?(trimmed, "Ns ") and current != nil ->
          case extract_floats(trimmed) do
            [ns] ->
              updated_mat = Map.update!(mats, current, fn mat ->
                Map.put(mat, :shininess, ns)
              end)
              {updated_mat, current}

            _ ->
              {mats, current}
          end

        # Transparency: d value or Tr value
        (String.starts_with?(trimmed, "d ") or String.starts_with?(trimmed, "Tr ")) and current != nil ->
          case extract_floats(trimmed) do
            [d] ->
              updated_mat = Map.update!(mats, current, fn mat ->
                Map.put(mat, :transparency, d)
              end)
              {updated_mat, current}

            _ ->
              {mats, current}
          end

        # Illumination model: illum value
        String.starts_with?(trimmed, "illum ") and current != nil ->
          case Integer.parse(String.slice(trimmed, 6, String.length(trimmed) - 6) |> String.trim()) do
            {illum, _} ->
              updated_mat = Map.update!(mats, current, fn mat ->
                Map.put(mat, :illum, illum)
              end)
              {updated_mat, current}

            :error ->
              {mats, current}
          end

        # Other commands (map_Kd, etc.) - ignore for now
        true ->
          {mats, current}
      end
    end)
    |> elem(0)
  end

  @doc """
  Converts OBJ 1-based indices to 0-based indices.

  OBJ format uses 1-based indexing, but many internal formats use 0-based.
  This function converts face indices from 1-based to 0-based.

  ## Examples

      # OBJ face: f 1 2 3
      # Converted: [{0, nil, nil}, {1, nil, nil}, {2, nil, nil}]
  """
  @spec convert_to_zero_based(Document.t()) :: Document.t()
  def convert_to_zero_based(%Document{} = document) do
    Document.convert_to_zero_based(document)
  end
end

