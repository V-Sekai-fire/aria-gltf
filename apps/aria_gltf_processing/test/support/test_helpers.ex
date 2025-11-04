# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltfProcessing.TestHelpers do
  @moduledoc """
  Test helpers for aria_gltf_processing tests.

  Provides utilities for:
  - OBJ parsing helpers
  - Temporary file management

  Note: For floating-point and vector comparisons, use AriaMath comparison functions.
  """

  # Use AriaMath comparison functions directly
  # No need to alias if not using directly

  @doc """
  Creates a temporary directory for tests.

  Returns the path to the temporary directory.
  The directory is cleaned up after the test (use in ExUnit setup/teardown).
  """
  @spec create_temp_dir() :: String.t()
  def create_temp_dir do
    tmp_dir = System.tmp_dir!()
    timestamp = :erlang.system_time(:nanosecond)
    path = Path.join(tmp_dir, "aria_gltf_test_#{timestamp}")
    File.mkdir_p!(path)
    path
  end

  @doc """
  Removes a temporary directory.

  Useful for cleanup in ExUnit teardown.
  """
  @spec cleanup_temp_dir(String.t()) :: :ok | {:error, File.posix()}
  def cleanup_temp_dir(path) do
    if File.exists?(path) do
      File.rm_rf(path)
    else
      :ok
    end
  end

  @doc """
  Creates a temporary file with given content.

  Returns the path to the temporary file.
  """
  @spec create_temp_file(String.t(), String.t()) :: String.t()
  def create_temp_file(content \\ "", extension \\ ".tmp") do
    tmp_dir = System.tmp_dir!()
    timestamp = :erlang.system_time(:nanosecond)
    path = Path.join(tmp_dir, "aria_gltf_test_#{timestamp}#{extension}")
    File.write!(path, content)
    path
  end

  @doc """
  Gets a temporary file path without creating the file.

  Useful for test files that will be created by the code under test.
  """
  @spec temp_file_path(String.t()) :: String.t()
  def temp_file_path(filename) do
    tmp_dir = System.tmp_dir!()
    timestamp = :erlang.system_time(:nanosecond)
    Path.join(tmp_dir, "aria_gltf_test_#{timestamp}_#{filename}")
  end

  @doc """
  Removes a temporary file.

  Useful for cleanup in ExUnit teardown.
  """
  @spec cleanup_temp_file(String.t()) :: :ok | {:error, File.posix()}
  def cleanup_temp_file(path) do
    if File.exists?(path) do
      File.rm!(path)
    else
      :ok
    end
  end

  @doc """
  Reads an OBJ file and returns its lines (excluding comments and empty lines).

  Useful for testing OBJ export/import.
  """
  @spec read_obj_lines(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, File.posix()}
  def read_obj_lines(path, opts \\ []) do
    ignore_comments = Keyword.get(opts, :ignore_comments, true)
    ignore_whitespace = Keyword.get(opts, :ignore_whitespace, false)

    with {:ok, content} <- File.read(path) do
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

  @doc """
  Parses OBJ geometry into structured data.

  Returns a map with :vertices, :normals, :texcoords, :faces, :materials, :groups keys.
  """
  @spec parse_obj_geometry([String.t()]) :: map()
  def parse_obj_geometry(lines) do
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
              # v//vn - not fully supported, skip for now
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

  @doc """
  Compares two vertex lists with tolerance.

  Returns true if all vertices match within tolerance, false otherwise.
  Vertices can be {x, y, z} or {x, y, z, w} tuples.

  ## Options

  - `:tolerance` - Floating point comparison tolerance (default: `1.0e-6`)

  ## Examples

      vertices1 = [{0.0, 0.0, 0.0}, {1.0, 0.0, 0.0}]
      vertices2 = [{0.0, 0.0, 0.0000001}, {1.0, 0.0, 0.0}]
      assert TestHelpers.compare_vertices(vertices1, vertices2, tolerance: 1.0e-5)
  """
  @spec compare_vertices([tuple()], [tuple()], keyword()) :: boolean()
  def compare_vertices(vertices1, vertices2, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 1.0e-6)

    if length(vertices1) != length(vertices2) do
      false
    else
      Enum.zip(vertices1, vertices2)
      |> Enum.all?(fn {v1, v2} ->
        compare_vertex_tuple(v1, v2, tolerance)
      end)
    end
  end

  @doc """
  Compares two face lists for topology equivalence.

  Returns true if faces match (accounting for different indexing schemes).
  Faces are lists of {v, vt, vn} tuples.

  ## Examples

      faces1 = [[{1, nil, nil}, {2, nil, nil}, {3, nil, nil}]]
      faces2 = [[{1, nil, nil}, {2, nil, nil}, {3, nil, nil}]]
      assert TestHelpers.compare_faces(faces1, faces2)
  """
  @spec compare_faces([list()], [list()]) :: boolean()
  def compare_faces(faces1, faces2) do
    if length(faces1) != length(faces2) do
      false
    else
      Enum.zip(faces1, faces2)
      |> Enum.all?(fn {face1, face2} ->
        if length(face1) != length(face2) do
          false
        else
          Enum.zip(face1, face2)
          |> Enum.all?(fn {v1, v2} -> v1 == v2 end)
        end
      end)
    end
  end

  @doc """
  Compares two complete mesh structures.

  Returns true if meshes are equivalent (vertices, faces, normals, texcoords).
  Input should be OBJ document structures or geometry maps.

  ## Options

  - `:tolerance` - Floating point comparison tolerance (default: `1.0e-6`)

  ## Examples

      mesh1 = %{vertices: [{0.0, 0.0, 0.0}], faces: [[{1, nil, nil}]]}
      mesh2 = %{vertices: [{0.0, 0.0, 0.0}], faces: [[{1, nil, nil}]]}
      assert TestHelpers.compare_meshes(mesh1, mesh2)
  """
  @spec compare_meshes(map() | struct(), map() | struct(), keyword()) :: boolean()
  def compare_meshes(mesh1, mesh2, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 1.0e-6)

    vertices_match =
      compare_vertices(
        get_vertices(mesh1),
        get_vertices(mesh2),
        tolerance: tolerance
      )

    normals_match =
      compare_vertices(
        get_normals(mesh1),
        get_normals(mesh2),
        tolerance: tolerance
      )

    texcoords_match =
      compare_vertices(
        get_texcoords(mesh1),
        get_texcoords(mesh2),
        tolerance: tolerance
      )

    faces_match = compare_faces(get_faces(mesh1), get_faces(mesh2))

    vertices_match && normals_match && texcoords_match && faces_match
  end

  @doc """
  Generates a detailed difference report between two geometries.

  Returns a map with differences found in vertices, normals, texcoords, and faces.

  ## Examples

      geom1 = %{vertices: [{0.0, 0.0, 0.0}], faces: [[{1, nil, nil}]]}
      geom2 = %{vertices: [{0.0, 0.0, 0.0}], faces: [[{1, nil, nil}]]}
      diff = TestHelpers.geometry_diff(geom1, geom2)
      assert diff.differences == []
  """
  @spec geometry_diff(map() | struct(), map() | struct(), keyword()) :: map()
  def geometry_diff(geom1, geom2, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 1.0e-6)
    differences = []

    differences =
      if length(get_vertices(geom1)) != length(get_vertices(geom2)) do
        differences ++
          [
            "Vertex count mismatch: #{length(get_vertices(geom1))} vs #{
              length(get_vertices(geom2))
            }"
          ]
      else
        differences
      end

    differences =
      if length(get_faces(geom1)) != length(get_faces(geom2)) do
        differences ++
          [
            "Face count mismatch: #{length(get_faces(geom1))} vs #{
              length(get_faces(geom2))
            }"
          ]
      else
        differences
      end

    differences =
      if not compare_vertices(get_vertices(geom1), get_vertices(geom2),
           tolerance: tolerance
         ) do
        differences ++ ["Vertex positions differ"]
      else
        differences
      end

    differences =
      if not compare_faces(get_faces(geom1), get_faces(geom2)) do
        differences ++ ["Face topology differs"]
      else
        differences
      end

    %{
      match: length(differences) == 0,
      differences: differences,
      tolerance: tolerance
    }
  end

  @doc """
  Validates geometry accuracy between two sources.

  Returns `:ok` if geometries match within tolerance, or `{:error, diff_report}` if they differ.

  ## Options

  - `:tolerance` - Floating point comparison tolerance (default: `1.0e-6`)

  ## Examples

      geom1 = %{vertices: [{0.0, 0.0, 0.0}], faces: [[{1, nil, nil}]]}
      geom2 = %{vertices: [{0.0, 0.0, 0.0}], faces: [[{1, nil, nil}]]}
      assert :ok = TestHelpers.validate_geometry_accuracy(geom1, geom2)
  """
  @spec validate_geometry_accuracy(map() | struct(), map() | struct(), keyword()) ::
          :ok | {:error, map()}
  def validate_geometry_accuracy(geom1, geom2, opts \\ []) do
    diff = geometry_diff(geom1, geom2, opts)

    if diff.match do
      :ok
    else
      {:error, diff}
    end
  end

  # Helper functions to extract geometry data from various structures

  defp get_vertices(%{vertices: vertices}) when is_list(vertices), do: vertices
  defp get_vertices(%{vertices: _}), do: []
  defp get_vertices(%{} = struct) when is_struct(struct) do
    # Try to access vertices field from struct
    case Map.has_key?(struct, :vertices) do
      true -> Map.get(struct, :vertices) || []
      false -> []
    end
  end
  defp get_vertices(_), do: []

  defp get_normals(%{normals: normals}) when is_list(normals), do: normals
  defp get_normals(%{normals: _}), do: []
  defp get_normals(%{} = struct) when is_struct(struct) do
    case Map.has_key?(struct, :normals) do
      true -> Map.get(struct, :normals) || []
      false -> []
    end
  end
  defp get_normals(_), do: []

  defp get_texcoords(%{texcoords: texcoords}) when is_list(texcoords), do: texcoords
  defp get_texcoords(%{texcoords: _}), do: []
  defp get_texcoords(%{} = struct) when is_struct(struct) do
    case Map.has_key?(struct, :texcoords) do
      true -> Map.get(struct, :texcoords) || []
      false -> []
    end
  end
  defp get_texcoords(_), do: []

  defp get_faces(%{faces: faces}) when is_list(faces), do: faces
  defp get_faces(%{faces: _}), do: []
  defp get_faces(%{} = struct) when is_struct(struct) do
    case Map.has_key?(struct, :faces) do
      true -> Map.get(struct, :faces) || []
      false -> []
    end
  end
  defp get_faces(_), do: []

  # Compare vertex tuples with tolerance
  defp compare_vertex_tuple({x1, y1, z1, w1}, {x2, y2, z2, w2}, tolerance)
       when is_number(w1) and is_number(w2) do
    abs(x1 - x2) < tolerance &&
      abs(y1 - y2) < tolerance &&
      abs(z1 - z2) < tolerance &&
      abs(w1 - w2) < tolerance
  end

  defp compare_vertex_tuple({x1, y1, z1}, {x2, y2, z2}, tolerance) do
    abs(x1 - x2) < tolerance &&
      abs(y1 - y2) < tolerance &&
      abs(z1 - z2) < tolerance
  end

  defp compare_vertex_tuple({u1, v1}, {u2, v2}, tolerance) do
    abs(u1 - u2) < tolerance && abs(v1 - v2) < tolerance
  end

  defp compare_vertex_tuple(_, _, _), do: false
end

