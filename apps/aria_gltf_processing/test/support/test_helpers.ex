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
end

