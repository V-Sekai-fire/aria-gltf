# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.SampleAssetValidator do
  @moduledoc """
  Validates glTF sample assets from glTF-Sample-Assets repository.

  This module provides utilities for loading and validating glTF models
  from the official glTF-Sample-Assets repository to ensure validation
  works correctly on real-world assets.
  """

  alias AriaGltf.{IO, Validation}
  alias AriaGltf.Validation.Report

  @type validation_result :: %{
          file_path: String.t(),
          success: boolean(),
          errors: [String.t()],
          warnings: [String.t()],
          validation_time_ms: float(),
          file_size_bytes: integer(),
          stats: map()
        }

  @doc """
  Validates a single glTF sample asset.

  ## Parameters

  - `file_path`: Path to the glTF file

  ## Options

  - `:validation_mode` - Validation mode `:strict`, `:permissive`, or `:warning_only` (default: `:strict`)
  - `:quick` - Skip detailed validation for faster testing (default: `false`)

  ## Returns

  `{:ok, validation_result}` on success, `{:error, reason}` on failure.

  ## Examples

      {:ok, result} = AriaGltf.Validation.SampleAssetValidator.validate_sample(
        "/path/to/Box.gltf"
      )
  """
  @spec validate_sample(String.t(), keyword()) ::
          {:ok, validation_result()} | {:error, term()}
  def validate_sample(file_path, opts \\ []) when is_binary(file_path) do
    validation_mode = Keyword.get(opts, :validation_mode, :strict)
    quick = Keyword.get(opts, :quick, false)

    start_time = System.monotonic_time(:millisecond)
    file_size = get_file_size(file_path)

    case IO.import_from_file(file_path, validation_mode: validation_mode) do
      {:ok, document} ->
        end_time = System.monotonic_time(:millisecond)
        validation_time_ms = end_time - start_time

        # Perform additional validation if not in quick mode
        validation_result =
          if quick do
            %{
              file_path: file_path,
              success: true,
              errors: [],
              warnings: [],
              validation_time_ms: validation_time_ms,
              file_size_bytes: file_size,
              stats: basic_stats(document)
            }
          else
            case Validation.validate(document, mode: validation_mode) do
              {:ok, _validated_doc} ->
                %{
                  file_path: file_path,
                  success: true,
                  errors: [],
                  warnings: [],
                  validation_time_ms: validation_time_ms,
                  file_size_bytes: file_size,
                  stats: detailed_stats(document)
                }

              {:error, %Report{} = report} ->
                errors = Enum.map(report.errors, &format_error/1)
                warnings = Enum.map(report.warnings, &format_warning/1)

                %{
                  file_path: file_path,
                  success: length(errors) == 0,
                  errors: errors,
                  warnings: warnings,
                  validation_time_ms: validation_time_ms,
                  file_size_bytes: file_size,
                  stats: basic_stats(document)
                }
            end
          end

        {:ok, validation_result}

      {:error, %Report{} = report} ->
        end_time = System.monotonic_time(:millisecond)
        validation_time_ms = end_time - start_time

        errors = Enum.map(report.errors, &format_error/1)
        warnings = Enum.map(report.warnings, &format_warning/1)

        result = %{
          file_path: file_path,
          success: false,
          errors: errors,
          warnings: warnings,
          validation_time_ms: validation_time_ms,
          file_size_bytes: file_size,
          stats: %{}
        }

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates multiple glTF sample assets.

  ## Parameters

  - `file_paths`: List of paths to glTF files

  ## Options

  - `:validation_mode` - Validation mode (default: `:strict`)
  - `:quick` - Skip detailed validation (default: `false`)
  - `:parallel` - Validate files in parallel (default: `false`)

  ## Returns

  List of validation results.

  ## Examples

      results = AriaGltf.Validation.SampleAssetValidator.validate_samples([
        "/path/to/Box.gltf",
        "/path/to/Cube.gltf"
      ])
  """
  @spec validate_samples([String.t()], keyword()) :: [validation_result()]
  def validate_samples(file_paths, opts \\ []) when is_list(file_paths) do
    parallel = Keyword.get(opts, :parallel, false)

    if parallel do
      file_paths
      |> Task.async_stream(
        fn path -> validate_sample(path, opts) end,
        max_concurrency: System.schedulers_online(),
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, {:ok, result}} -> result
        {:ok, {:error, reason}} -> create_error_result(reason)
        {:exit, reason} -> create_error_result(reason)
      end)
    else
      Enum.map(file_paths, fn path ->
        case validate_sample(path, opts) do
          {:ok, result} -> result
          {:error, reason} -> create_error_result(reason)
        end
      end)
    end
  end

  @doc """
  Validates all glTF files in a directory.

  ## Parameters

  - `directory`: Path to directory containing glTF files

  ## Options

  - `:recursive` - Search recursively (default: `true`)
  - `:pattern` - File pattern to match (default: `"*.gltf"`)
  - Other options same as `validate_samples/2`

  ## Returns

  List of validation results.

  ## Examples

      results = AriaGltf.Validation.SampleAssetValidator.validate_directory(
        "/Users/ernest.lee/Developer/glTF-Sample-Assets/Models"
      )
  """
  @spec validate_directory(String.t(), keyword()) :: [validation_result()]
  def validate_directory(directory, opts \\ []) when is_binary(directory) do
    recursive = Keyword.get(opts, :recursive, true)
    pattern = Keyword.get(opts, :pattern, "*.gltf")

    file_paths =
      if recursive do
        Path.join(directory, "**/#{pattern}")
        |> Path.wildcard()
      else
        Path.join(directory, pattern)
        |> Path.wildcard()
      end
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(fn path ->
        # Filter out embedded/quantized/draco/binary variants
        not String.contains?(path, ["Embedded", "Quantized", "Draco", "Binary"])
      end)

    validate_samples(file_paths, opts)
  end

  @doc """
  Validates vendor-specific small test cases.

  Focuses on small test models from glTF-Sample-Assets that are designed
  to test specific features. These are typically simple models used for
  conformance testing.

  ## Parameters

  - `base_path`: Base path to glTF-Sample-Assets directory (default: from env or current)

  ## Options

  - `:test_only` - Only validate models with "Test" in name (default: `true`)
  - `:max_file_size_kb` - Maximum file size in KB (default: `100`)
  - `:max_lines` - Maximum lines in file (default: `200`)
  - `:parallel` - Validate in parallel (default: `true`)
  - Other options same as `validate_samples/2`

  ## Returns

  Summary with validation results.

  ## Examples

      summary = AriaGltf.Validation.SampleAssetValidator.validate_vendor_small_tests(
        "/Users/ernest.lee/Developer/glTF-Sample-Assets"
      )
  """
  @spec validate_vendor_small_tests(String.t() | nil, keyword()) :: map()
  def validate_vendor_small_tests(base_path \\ nil, opts \\ []) do
    base_path = base_path || "/Users/ernest.lee/Developer/glTF-Sample-Assets"
    test_only = Keyword.get(opts, :test_only, true)
    max_file_size_kb = Keyword.get(opts, :max_file_size_kb, 100)
    max_lines = Keyword.get(opts, :max_lines, 200)

    models_dir = Path.join(base_path, "Models")

    # Find all glTF files
    file_paths =
      Path.join(models_dir, "**/*.gltf")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(fn path ->
        # Filter out variants
        not String.contains?(path, ["Embedded", "Quantized", "Draco", "Binary"])
      end)
      |> Enum.filter(fn path ->
        # Filter by test name if requested
        if test_only do
          String.contains?(Path.basename(path, ".gltf"), "Test") ||
            String.contains?(Path.dirname(path), "Test")
        else
          true
        end
      end)
      |> Enum.filter(fn path ->
        # Filter by file size
        case File.stat(path) do
          {:ok, stat} ->
            file_size_kb = stat.size / 1024
            file_size_kb <= max_file_size_kb

          {:error, _} ->
            false
        end
      end)
      |> Enum.filter(fn path ->
        # Filter by line count
        case File.read(path) do
          {:ok, content} ->
            line_count = content |> String.split("\n") |> length()
            line_count <= max_lines

          {:error, _} ->
            false
        end
      end)
      |> Enum.sort()

    results = validate_samples(file_paths, opts)

    summary(results)
    |> Map.put(:vendor_test_files, file_paths)
    |> Map.put(:test_criteria, %{
      test_only: test_only,
      max_file_size_kb: max_file_size_kb,
      max_lines: max_lines
    })
  end

  @doc """
  Generates a validation summary report.

  ## Parameters

  - `results`: List of validation results

  ## Options

  - `:detailed` - Include detailed per-file results (default: `false`)

  ## Returns

  Summary statistics map.

  ## Examples

      results = AriaGltf.Validation.SampleAssetValidator.validate_samples([...])
      summary = AriaGltf.Validation.SampleAssetValidator.summary(results)
      summary = AriaGltf.Validation.SampleAssetValidator.summary(results, detailed: true)
  """
  @spec summary([validation_result()], keyword()) :: map()
  def summary(results, opts \\ []) when is_list(results) do
    detailed = Keyword.get(opts, :detailed, false)

    total = length(results)
    successful = Enum.count(results, & &1.success)
    failed = total - successful

    total_errors = results |> Enum.map(&length(&1.errors)) |> Enum.sum()
    total_warnings = results |> Enum.map(&length(&1.warnings)) |> Enum.sum()

    total_time_ms =
      results |> Enum.map(& &1.validation_time_ms) |> Enum.sum()

    avg_time_ms = if total > 0, do: total_time_ms / total, else: 0.0

    total_size_bytes =
      results |> Enum.map(& &1.file_size_bytes) |> Enum.sum()

    failed_files =
      results
      |> Enum.filter(&not &1.success)
      |> Enum.map(& &1.file_path)

    base_summary = %{
      total_files: total,
      successful: successful,
      failed: failed,
      success_rate: if(total > 0, do: successful / total, else: 0.0),
      total_errors: total_errors,
      total_warnings: total_warnings,
      total_validation_time_ms: total_time_ms,
      average_validation_time_ms: avg_time_ms,
      total_file_size_bytes: total_size_bytes,
      failed_files: failed_files
    }

    if detailed do
      Map.put(base_summary, :results, results)
    else
      base_summary
    end
  end

  # Private helper functions

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, stat} -> stat.size
      {:error, _} -> 0
    end
  end

  defp basic_stats(document) do
    %{
      version: document.asset && document.asset.version,
      node_count: length(document.nodes || []),
      mesh_count: length(document.meshes || []),
      material_count: length(document.materials || []),
      animation_count: length(document.animations || []),
      skin_count: length(document.skins || [])
    }
  end

  defp detailed_stats(document) do
    basic_stats(document)
    |> Map.merge(%{
      accessor_count: length(document.accessors || []),
      buffer_count: length(document.buffers || []),
      buffer_view_count: length(document.buffer_views || []),
      texture_count: length(document.textures || []),
      image_count: length(document.images || []),
      sampler_count: length(document.samplers || []),
      camera_count: length(document.cameras || []),
      scene_count: length(document.scenes || [])
    })
  end

  defp format_error(error) do
    case error do
      %{location: location, message: message} ->
        "#{inspect(location)}: #{message}"

      {location, message} when is_atom(location) or is_tuple(location) ->
        "#{inspect(location)}: #{message}"

      message when is_binary(message) ->
        message

      other ->
        inspect(other)
    end
  end

  defp format_warning(warning) do
    case warning do
      %{location: location, message: message} ->
        "#{inspect(location)}: #{message}"

      {location, message} when is_atom(location) or is_tuple(location) ->
        "#{inspect(location)}: #{message}"

      message when is_binary(message) ->
        message

      other ->
        inspect(other)
    end
  end

  defp create_error_result(reason) do
    %{
      file_path: "",
      success: false,
      errors: ["Load error: #{inspect(reason)}"],
      warnings: [],
      validation_time_ms: 0.0,
      file_size_bytes: 0,
      stats: %{}
    }
  end
end

