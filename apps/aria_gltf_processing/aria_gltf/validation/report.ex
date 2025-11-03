# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.Report do
  @moduledoc """
  Validation report containing errors and warnings from glTF validation.

  This module represents the result of a validation operation, containing
  all errors and warnings found, along with metadata about the validation.
  """

  alias AriaGltf.Validation.{Error, Warning}

  @type validation_mode :: :strict | :permissive | :warning_only

  @type t :: %__MODULE__{
          errors: [Error.t()],
          warnings: [Warning.t()],
          validation_mode: validation_mode(),
          duration_ms: integer(),
          validated_at: DateTime.t()
        }

  defstruct errors: [],
            warnings: [],
            validation_mode: :strict,
            duration_ms: 0,
            validated_at: nil

  @doc """
  Creates a new validation report.
  """
  @spec new([Error.t()], [Warning.t()], validation_mode()) :: t()
  def new(errors \\ [], warnings \\ [], mode \\ :strict) do
    %__MODULE__{
      errors: errors,
      warnings: warnings,
      validation_mode: mode,
      validated_at: DateTime.utc_now()
    }
  end

  @doc """
  Checks if the report has any errors.
  """
  @spec has_errors?(t()) :: boolean()
  def has_errors?(%__MODULE__{errors: errors}), do: length(errors) > 0

  @doc """
  Checks if the report has any warnings.
  """
  @spec has_warnings?(t()) :: boolean()
  def has_warnings?(%__MODULE__{warnings: warnings}), do: length(warnings) > 0

  @doc """
  Checks if the report has any critical errors.
  """
  @spec has_critical_errors?(t()) :: boolean()
  def has_critical_errors?(%__MODULE__{errors: errors}) do
    Enum.any?(errors, &Error.critical?/1)
  end

  @doc """
  Gets the total count of issues (errors + warnings).
  """
  @spec issue_count(t()) :: integer()
  def issue_count(%__MODULE__{errors: errors, warnings: warnings}) do
    length(errors) + length(warnings)
  end

  @doc """
  Gets the error count.
  """
  @spec error_count(t()) :: integer()
  def error_count(%__MODULE__{errors: errors}), do: length(errors)

  @doc """
  Gets the warning count.
  """
  @spec warning_count(t()) :: integer()
  def warning_count(%__MODULE__{warnings: warnings}), do: length(warnings)

  @doc """
  Checks if the validation was successful (no errors in strict mode, no critical errors in permissive mode).
  """
  @spec successful?(t()) :: boolean()
  def successful?(%__MODULE__{validation_mode: :strict} = report) do
    not has_errors?(report)
  end

  def successful?(%__MODULE__{validation_mode: :permissive} = report) do
    not has_critical_errors?(report)
  end

  def successful?(%__MODULE__{validation_mode: :warning_only}), do: true

  @doc """
  Formats the report as a human-readable string.
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = report) do
    parts = []

    # Header
    parts = [format_header(report) | parts]

    # Errors
    if has_errors?(report) do
      ^parts = [format_errors(report.errors) | parts]
    end

    # Warnings
    if has_warnings?(report) do
      ^parts = [format_warnings(report.warnings) | parts]
    end

    # Summary
    parts = [format_summary(report) | parts]

    parts
    |> Enum.reverse()
    |> Enum.join("\n\n")
  end

  defp format_header(%__MODULE__{
         validation_mode: mode,
         validated_at: timestamp,
         duration_ms: duration
       }) do
    timestamp_str = if timestamp, do: DateTime.to_iso8601(timestamp), else: "unknown"

    """
    glTF Validation Report
    Mode: #{mode}
    Validated at: #{timestamp_str}
    Duration: #{duration}ms
    """
  end

  defp format_errors(errors) do
    error_lines =
      Enum.map(errors, fn error ->
        "  #{Error.format_location(error.location)}: #{error.message}"
      end)

    ["ERRORS:", error_lines]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp format_warnings(warnings) do
    warning_lines =
      Enum.map(warnings, fn warning ->
        "  #{Warning.format_location(warning.location)}: #{warning.message}"
      end)

    ["WARNINGS:", warning_lines]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp format_summary(%__MODULE__{} = report) do
    error_count = error_count(report)
    warning_count = warning_count(report)
    success = if successful?(report), do: "PASSED", else: "FAILED"

    "SUMMARY: #{success} - #{error_count} errors, #{warning_count} warnings"
  end

  @doc """
  Converts the report to a JSON-serializable map.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = report) do
    %{
      "errors" => Enum.map(report.errors, &Error.to_json/1),
      "warnings" => Enum.map(report.warnings, &Warning.to_json/1),
      "validation_mode" => Atom.to_string(report.validation_mode),
      "duration_ms" => report.duration_ms,
      "validated_at" => if(report.validated_at, do: DateTime.to_iso8601(report.validated_at)),
      "summary" => %{
        "error_count" => error_count(report),
        "warning_count" => warning_count(report),
        "successful" => successful?(report)
      }
    }
  end
end
