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
    # TODO: 2025-11-03 fire - Implement proper OBJ file comparison
    # Need to:
    # - Parse OBJ lines (v, vn, vt, f)
    # - Compare geometry data with tolerance
    # - Handle different ordering of elements
    # - Account for floating point precision differences

    # For now, simple line-by-line comparison
    if length(output_lines) != length(ref_lines) do
      false
    else
      Enum.zip(output_lines, ref_lines)
      |> Enum.all?(fn {out_line, ref_line} ->
        compare_obj_line(out_line, ref_line, tolerance)
      end)
    end
  end

  defp compare_obj_line(out_line, ref_line, tolerance) do
    # Parse OBJ line types
    out_type = String.slice(out_line, 0, 2) |> String.trim()
    ref_type = String.slice(ref_line, 0, 2) |> String.trim()

    if out_type != ref_type do
      false
    else
      # Extract numeric values and compare with tolerance
      out_values = extract_numeric_values(out_line)
      ref_values = extract_numeric_values(ref_line)

      if length(out_values) != length(ref_values) do
        false
      else
        Enum.zip(out_values, ref_values)
        |> Enum.all?(fn {out_val, ref_val} ->
          abs(out_val - ref_val) < tolerance
        end)
      end
    end
  end

  defp extract_numeric_values(line) do
    # Extract all floating point numbers from OBJ line
    Regex.scan(~r/-?\d+\.?\d*(?:[eE][+-]?\d+)?/, line)
    |> Enum.map(fn [match] -> String.to_float(match) end)
    |> Enum.reject(&is_nil/1)
  end

  defp compute_obj_diff(output_lines, ref_lines) do
    # TODO: 2025-11-03 fire - Implement detailed diff computation
    # Should show:
    # - Line-by-line differences
    # - Missing/extra elements
    # - Geometry differences summary
    %{
      output_count: length(output_lines),
      reference_count: length(ref_lines),
      differences: []
    }
  end
end

