# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaDocument.Converter do
  @moduledoc """
  Document format conversion utilities.

  Provides conversion pipelines between different 3D file formats:
  - FBX -> Internal Format (FBXDocument)
  - Internal Format -> OBJ
  - FBX -> Internal Format -> OBJ (complete pipeline)

  Supports ufbx test validation methodology with FBX + OBJ sequences.
  """

  alias AriaFbx.{Document, Import}
  alias AriaDocument.Export.Obj

  @doc """
  Converts an FBX file to OBJ format.

  Pipeline: FBX -> Internal Format (FBXDocument) -> OBJ

  ## Options

  - `:mtl_file` - Generate MTL material file (default: `true`)
  - `:validate` - Validate FBX during import (default: `true`)
  - `:output_dir` - Directory for output files (default: directory of output_path)

  ## Examples

      {:ok, obj_path} = AriaDocument.Converter.fbx_to_obj("/path/to/model.fbx", "/path/to/output.obj")
      {:ok, obj_path} = AriaDocument.Converter.fbx_to_obj("/path/to/model.fbx", "/path/to/output.obj", mtl_file: false)
  """
  @spec fbx_to_obj(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def fbx_to_obj(fbx_path, obj_path, opts \\ []) do
    with {:ok, fbx_document} <- Import.from_file(fbx_path, validate: Keyword.get(opts, :validate, true)),
         {:ok, _obj_path} <- Obj.export(fbx_document, obj_path, opts) do
      {:ok, obj_path}
    end
  end

  @doc """
  Converts a directory of FBX files to OBJ format.

  Useful for batch processing ufbx test sequences (FBX + OBJ pairs).

  ## Options

  - `:mtl_file` - Generate MTL material files (default: `true`)
  - `:validate` - Validate FBX during import (default: `true`)
  - `:pattern` - File pattern to match (default: `"*.fbx"`)
  - `:output_dir` - Output directory for OBJ files (default: same as input directory)
  - `:recursive` - Search subdirectories (default: `true`)

  ## Examples

      {:ok, results} = AriaDocument.Converter.fbx_dir_to_obj("/path/to/fbx/directory")
      # Returns: {:ok, [successful_paths, error_paths]}
  """
  @spec fbx_dir_to_obj(String.t(), keyword()) ::
          {:ok, {[String.t()], [String.t()]}} | {:error, term()}
  def fbx_dir_to_obj(dir_path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, "*.fbx")
    recursive = Keyword.get(opts, :recursive, true)
    output_dir = Keyword.get(opts, :output_dir, dir_path)

    fbx_files =
      if recursive do
        Path.join([dir_path, "**", pattern]) |> Path.wildcard()
      else
        Path.join([dir_path, pattern]) |> Path.wildcard()
      end

    results =
      Enum.reduce(fbx_files, {[], []}, fn fbx_path, {successes, errors} ->
        obj_path = Path.join(output_dir, Path.basename(fbx_path, ".fbx") <> ".obj")

        case fbx_to_obj(fbx_path, obj_path, opts) do
          {:ok, _} -> {[obj_path | successes], errors}
          {:error, reason} -> {successes, [{fbx_path, reason} | errors]}
        end
      end)

    {:ok, {Enum.reverse(elem(results, 0)), Enum.reverse(elem(results, 1))}}
  end

  @doc """
  Validates FBX -> OBJ conversion by comparing with reference OBJ files.

  This function is designed for ufbx test validation methodology:
  - Loads FBX file
  - Converts to OBJ
  - Compares with reference OBJ file (if it exists in same directory)

  ## Options

  - `:tolerance` - Floating point comparison tolerance (default: `1.0e-6`)
  - `:ignore_comments` - Ignore comment lines in OBJ comparison (default: `true`)
  - `:ignore_whitespace` - Ignore whitespace differences (default: `false`)

  ## Returns

  - `{:ok, :match}` - Output matches reference
  - `{:ok, :no_reference}` - No reference OBJ file found
  - `{:ok, :mismatch, diff}` - Output differs from reference
  - `{:error, reason}` - Conversion or comparison error

  ## Examples

      {:ok, result} = AriaDocument.Converter.validate_fbx_to_obj("/path/to/model.fbx")
      # {:ok, :match} - Successfully matches reference
      # {:ok, :mismatch, diff} - Differences found
  """
  @spec validate_fbx_to_obj(String.t(), keyword()) ::
          {:ok, :match | :no_reference | {:mismatch, term()}} | {:error, term()}
  def validate_fbx_to_obj(fbx_path, opts \\ []) do
    ref_obj_path = Path.rootname(fbx_path, ".fbx") <> ".obj"

    with {:ok, output_obj_path} <- convert_fbx_to_obj_temp(fbx_path, opts) do
      if File.exists?(ref_obj_path) do
        compare_obj_files(output_obj_path, ref_obj_path, opts)
      else
        {:ok, :no_reference}
      end
    end
  end

  @doc """
  Validates multiple FBX files against reference OBJ sequences.

  Processes all FBX files in a directory and validates against their
  corresponding OBJ reference files (following ufbx test pattern).

  ## Returns

  - `{:ok, summary}` - Summary map with:
    - `:total` - Total files processed
    - `:matched` - Files that matched reference
    - `:mismatched` - Files with differences
    - `:no_reference` - Files without reference OBJ
    - `:errors` - Conversion errors

  ## Examples

      {:ok, summary} = AriaDocument.Converter.validate_fbx_sequences("/path/to/test/data")
      # %{total: 100, matched: 95, mismatched: 3, no_reference: 1, errors: 1}
  """
  @spec validate_fbx_sequences(String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def validate_fbx_sequences(dir_path, opts \\ []) do
    pattern = Keyword.get(opts, :pattern, "*.fbx")
    recursive = Keyword.get(opts, :recursive, true)

    fbx_files =
      if recursive do
        Path.join([dir_path, "**", pattern]) |> Path.wildcard()
      else
        Path.join([dir_path, pattern]) |> Path.wildcard()
      end

    results =
      Enum.reduce(fbx_files, %{matched: 0, mismatched: 0, no_reference: 0, errors: 0}, fn fbx_path,
                                                                                           acc ->
        case validate_fbx_to_obj(fbx_path, opts) do
          {:ok, :match} -> %{acc | matched: acc.matched + 1}
          {:ok, :no_reference} -> %{acc | no_reference: acc.no_reference + 1}
          {:ok, {:mismatch, _diff}} -> %{acc | mismatched: acc.mismatched + 1}
          {:error, _reason} -> %{acc | errors: acc.errors + 1}
        end
      end)

    summary = Map.put(results, :total, length(fbx_files))
    {:ok, summary}
  end

  # Private helper functions

  defp convert_fbx_to_obj_temp(fbx_path, opts) do
    # Create temporary output file
    temp_dir = System.tmp_dir()
    temp_file = Path.join(temp_dir, "#{Path.basename(fbx_path, ".fbx")}_converted.obj")

    fbx_to_obj(fbx_path, temp_file, opts)
  end

  defp compare_obj_files(output_path, reference_path, opts) do
    tolerance = Keyword.get(opts, :tolerance, 1.0e-6)
    ignore_comments = Keyword.get(opts, :ignore_comments, true)
    ignore_whitespace = Keyword.get(opts, :ignore_whitespace, false)

    with {:ok, output_lines} <- read_obj_lines(output_path, ignore_comments, ignore_whitespace),
         {:ok, ref_lines} <- read_obj_lines(reference_path, ignore_comments, ignore_whitespace) do
      if compare_obj_lines(output_lines, ref_lines, tolerance) do
        {:ok, :match}
      else
        diff = compute_obj_diff(output_lines, ref_lines)
        {:ok, {:mismatch, diff}}
      end
    end
  end

  defp read_obj_lines(file_path, ignore_comments, ignore_whitespace) do
    with {:ok, content} <- File.read(file_path) do
      lines =
        content
        |> String.split("\n")
        |> Enum.map(fn line ->
          if ignore_comments && String.starts_with?(String.trim_leading(line), "#") do
            nil
          else
            if ignore_whitespace do
              String.replace(line, ~r/\s+/, " ") |> String.trim()
            else
              line
            end
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(fn line -> ignore_whitespace && String.trim(line) == "" end)

      {:ok, lines}
    end
  end

  defp compare_obj_lines(output_lines, ref_lines, tolerance) do
    # Parse OBJ files into structured geometry data
    output_geom = parse_obj_geometry(output_lines)
    ref_geom = parse_obj_geometry(ref_lines)

    # Compare geometry with tolerance
    compare_geometry(output_geom, ref_geom, tolerance)
  end

  # Parse OBJ file into structured geometry
  defp parse_obj_geometry(lines) do
    Enum.reduce(lines, %{vertices: [], normals: [], texcoords: [], faces: [], materials: [], groups: []}, fn line, acc ->
      trimmed = String.trim(line)

      cond do
        # Skip comments and empty lines
        trimmed == "" or String.starts_with?(trimmed, "#") ->
          acc

        # Vertices: v x y z [w]
        String.starts_with?(trimmed, "v ") ->
          case parse_vertex_line(trimmed) do
            {:ok, vertex} -> %{acc | vertices: acc.vertices ++ [vertex]}
            :error -> acc
          end

        # Normals: vn x y z
        String.starts_with?(trimmed, "vn ") ->
          case parse_normal_line(trimmed) do
            {:ok, normal} -> %{acc | normals: acc.normals ++ [normal]}
            :error -> acc
          end

        # Texture coordinates: vt u v [w]
        String.starts_with?(trimmed, "vt ") ->
          case parse_texcoord_line(trimmed) do
            {:ok, texcoord} -> %{acc | texcoords: acc.texcoords ++ [texcoord]}
            :error -> acc
          end

        # Faces: f v1/vt1/vn1 v2/vt2/vn2 ...
        String.starts_with?(trimmed, "f ") ->
          case parse_face_line(trimmed) do
            {:ok, face} -> %{acc | faces: acc.faces ++ [face]}
            :error -> acc
          end

        # Material: usemtl material_name
        String.starts_with?(trimmed, "usemtl ") ->
          material = String.slice(trimmed, 7, String.length(trimmed) - 7) |> String.trim()
          %{acc | materials: acc.materials ++ [material]}

        # Object group: g group_name
        String.starts_with?(trimmed, "g ") ->
          group = String.slice(trimmed, 2, String.length(trimmed) - 2) |> String.trim()
          %{acc | groups: acc.groups ++ [group]}

        # Object name: o object_name
        String.starts_with?(trimmed, "o ") ->
          # Treat as group for comparison
          group = String.slice(trimmed, 2, String.length(trimmed) - 2) |> String.trim()
          %{acc | groups: acc.groups ++ [group]}

        # Other commands (mtllib, s, etc.) - ignore for geometry comparison
        true ->
          acc
      end
    end)
  end

  # Parse vertex line: v x y z [w]
  defp parse_vertex_line("v " <> rest) do
    values = extract_floats(rest)
    cond do
      length(values) == 4 -> {:ok, {Enum.at(values, 0), Enum.at(values, 1), Enum.at(values, 2), Enum.at(values, 3)}}
      length(values) == 3 -> {:ok, {Enum.at(values, 0), Enum.at(values, 1), Enum.at(values, 2)}}
      true -> :error
    end
  end
  defp parse_vertex_line(_), do: :error

  # Parse normal line: vn x y z
  defp parse_normal_line("vn " <> rest) do
    values = extract_floats(rest)
    cond do
      length(values) >= 3 -> {:ok, {Enum.at(values, 0), Enum.at(values, 1), Enum.at(values, 2)}}
      true -> :error
    end
  end
  defp parse_normal_line(_), do: :error

  # Parse texture coordinate line: vt u v [w]
  defp parse_texcoord_line("vt " <> rest) do
    values = extract_floats(rest)
    cond do
      length(values) >= 2 -> {:ok, {Enum.at(values, 0), Enum.at(values, 1)}}
      true -> :error
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
              # v//vn
              nil
            else
              case Integer.parse(vt_str) do
                {vt, _} -> {v, vt, nil}
                :error -> nil
              end
            end
          :error -> nil
        end

      length(parts) == 3 ->
        # v/vt/vn
        case {Integer.parse(Enum.at(parts, 0)), Integer.parse(Enum.at(parts, 1)), Integer.parse(Enum.at(parts, 2))} do
          {{v, _}, {vt, _}, {vn, _}} -> {v, vt, vn}
          _ -> nil
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

  # Compare parsed geometry with tolerance
  defp compare_geometry(output_geom, ref_geom, tolerance) do
    # Compare counts first
    if length(output_geom.vertices) != length(ref_geom.vertices) or
       length(output_geom.normals) != length(ref_geom.normals) or
       length(output_geom.texcoords) != length(ref_geom.texcoords) or
       length(output_geom.faces) != length(ref_geom.faces) do
      false
    else
      # Compare vertices with tolerance (order matters for OBJ)
      vertices_match =
        Enum.zip(output_geom.vertices, ref_geom.vertices)
        |> Enum.all?(fn {out_v, ref_v} ->
          compare_vertex(out_v, ref_v, tolerance)
        end)

      # Compare normals with tolerance
      normals_match =
        Enum.zip(output_geom.normals, ref_geom.normals)
        |> Enum.all?(fn {out_n, ref_n} ->
          compare_vec3(out_n, ref_n, tolerance)
        end)

      # Compare texture coordinates with tolerance
      texcoords_match =
        Enum.zip(output_geom.texcoords, ref_geom.texcoords)
        |> Enum.all?(fn {out_t, ref_t} ->
          compare_vec2(out_t, ref_t, tolerance)
        end)

      # Compare faces (order matters)
      faces_match =
        Enum.zip(output_geom.faces, ref_geom.faces)
        |> Enum.all?(fn {out_f, ref_f} ->
          compare_face(out_f, ref_f)
        end)

      vertices_match && normals_match && texcoords_match && faces_match
    end
  end

  # Compare vertex tuples (x, y, z, w) with tolerance
  defp compare_vertex({x1, y1, z1, w1}, {x2, y2, z2, w2}, tolerance) when is_number(w1) and is_number(w2) do
    abs(x1 - x2) < tolerance &&
    abs(y1 - y2) < tolerance &&
    abs(z1 - z2) < tolerance &&
    abs(w1 - w2) < tolerance
  end
  defp compare_vertex({x1, y1, z1}, {x2, y2, z2}, tolerance) do
    abs(x1 - x2) < tolerance &&
    abs(y1 - y2) < tolerance &&
    abs(z1 - z2) < tolerance
  end
  defp compare_vertex(_, _, _), do: false

  # Compare vec3 tuples with tolerance
  defp compare_vec3({x1, y1, z1}, {x2, y2, z2}, tolerance) do
    abs(x1 - x2) < tolerance &&
    abs(y1 - y2) < tolerance &&
    abs(z1 - z2) < tolerance
  end
  defp compare_vec3(_, _, _), do: false

  # Compare vec2 tuples with tolerance
  defp compare_vec2({u1, v1}, {u2, v2}, tolerance) do
    abs(u1 - u2) < tolerance &&
    abs(v1 - v2) < tolerance
  end
  defp compare_vec2(_, _, _), do: false

  # Compare face lists (exact match)
  defp compare_face(out_face, ref_face) do
    out_face == ref_face
  end

  defp compute_obj_diff(output_lines, ref_lines) do
    # Parse both OBJ files
    output_geom = parse_obj_geometry(output_lines)
    ref_geom = parse_obj_geometry(ref_lines)

    # Compute detailed differences
    differences = []

    # Count differences
    differences =
      if length(output_geom.vertices) != length(ref_geom.vertices) do
        differences ++
          [
            "Vertex count mismatch: output=#{length(output_geom.vertices)}, reference=#{
              length(ref_geom.vertices)
            }"
          ]
      else
        differences
      end

    differences =
      if length(output_geom.normals) != length(ref_geom.normals) do
        differences ++
          [
            "Normal count mismatch: output=#{length(output_geom.normals)}, reference=#{
              length(ref_geom.normals)
            }"
          ]
      else
        differences
      end

    differences =
      if length(output_geom.texcoords) != length(ref_geom.texcoords) do
        differences ++
          [
            "Texture coordinate count mismatch: output=#{length(output_geom.texcoords)}, reference=#{
              length(ref_geom.texcoords)
            }"
          ]
      else
        differences
      end

    differences =
      if length(output_geom.faces) != length(ref_geom.faces) do
        differences ++
          [
            "Face count mismatch: output=#{length(output_geom.faces)}, reference=#{
              length(ref_geom.faces)
            }"
          ]
      else
        differences
      end

    # Find vertex differences with tolerance
    vertex_diffs =
      Enum.with_index(output_geom.vertices)
      |> Enum.filter(fn {out_v, idx} ->
        ref_v = Enum.at(ref_geom.vertices, idx)
        ref_v && !compare_vertex(out_v, ref_v, 0.0001)
      end)
      |> Enum.map(fn {out_v, idx} ->
        "Vertex #{idx + 1} differs: output=#{inspect(out_v)}, reference=#{
          inspect(Enum.at(ref_geom.vertices, idx))
        }"
      end)

    differences = differences ++ vertex_diffs

    # Find face differences
    face_diffs =
      Enum.with_index(output_geom.faces)
      |> Enum.filter(fn {out_f, idx} ->
        ref_f = Enum.at(ref_geom.faces, idx)
        out_f != ref_f
      end)
      |> Enum.map(fn {out_f, idx} ->
        "Face #{idx + 1} differs: output=#{inspect(out_f)}, reference=#{
          inspect(Enum.at(ref_geom.faces, idx))
        }"
      end)

    differences = differences ++ face_diffs

    # Material and group differences
    material_diffs =
      if output_geom.materials != ref_geom.materials do
        [
          "Materials differ: output=#{inspect(output_geom.materials)}, reference=#{
            inspect(ref_geom.materials)
          }"
        ]
      else
        []
      end

    group_diffs =
      if output_geom.groups != ref_geom.groups do
        [
          "Groups differ: output=#{inspect(output_geom.groups)}, reference=#{
            inspect(ref_geom.groups)
          }"
        ]
      else
        []
      end

    differences = differences ++ material_diffs ++ group_diffs

    %{
      output_count: length(output_lines),
      reference_count: length(ref_lines),
      output_geometry: %{
        vertices: length(output_geom.vertices),
        normals: length(output_geom.normals),
        texcoords: length(output_geom.texcoords),
        faces: length(output_geom.faces),
        materials: length(output_geom.materials),
        groups: length(output_geom.groups)
      },
      reference_geometry: %{
        vertices: length(ref_geom.vertices),
        normals: length(ref_geom.normals),
        texcoords: length(ref_geom.texcoords),
        faces: length(ref_geom.faces),
        materials: length(ref_geom.materials),
        groups: length(ref_geom.groups)
      },
      differences: differences
    }
  end
end

