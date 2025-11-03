# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.Context do
  @moduledoc """
  Validation context that accumulates errors and warnings during validation.

  This module maintains the state during validation, collecting errors and warnings
  with their locations and severity levels.
  """

  alias AriaGltf.Document
  alias AriaGltf.Validation.{Report, Error, Warning}

  @type validation_mode :: :strict | :permissive | :warning_only
  @type error_location :: atom() | {atom(), integer()} | [atom() | integer()]

  @type t :: %__MODULE__{
          document: Document.t(),
          mode: validation_mode(),
          overrides: [atom()],
          errors: [Error.t()],
          warnings: [Warning.t()],
          start_time: DateTime.t()
        }

  defstruct [
    :document,
    :mode,
    overrides: [],
    errors: [],
    warnings: [],
    start_time: nil
  ]

  @doc """
  Creates a new validation context.
  """
  @spec new(Document.t(), validation_mode(), [atom()]) :: t()
  def new(%Document{} = document, mode \\ :strict, overrides \\ []) do
    %__MODULE__{
      document: document,
      mode: mode,
      overrides: overrides,
      errors: [],
      warnings: [],
      start_time: DateTime.utc_now()
    }
  end

  @doc """
  Checks if a specific validation check should be overridden.
  """
  @spec has_override?(t(), atom()) :: boolean()
  def has_override?(%__MODULE__{overrides: overrides}, check_name) do
    check_name in overrides
  end

  @doc """
  Adds an error to the validation context.
  """
  @spec add_error(t(), error_location(), String.t()) :: t()
  def add_error(%__MODULE__{} = context, location, message) do
    error = Error.new(location, message)
    %{context | errors: [error | context.errors]}
  end

  @doc """
  Adds a warning to the validation context.
  """
  @spec add_warning(t(), error_location(), String.t()) :: t()
  def add_warning(%__MODULE__{} = context, location, message) do
    warning = Warning.new(location, message)
    %{context | warnings: [warning | context.warnings]}
  end

  @doc """
  Checks if the context has any errors.
  """
  @spec has_errors?(t()) :: boolean()
  def has_errors?(%__MODULE__{errors: errors}), do: length(errors) > 0

  @doc """
  Checks if the context has any warnings.
  """
  @spec has_warnings?(t()) :: boolean()
  def has_warnings?(%__MODULE__{warnings: warnings}), do: length(warnings) > 0

  @doc """
  Checks if the context has any critical errors.
  Critical errors are those that prevent the document from being used.
  """
  @spec has_critical_errors?(t()) :: boolean()
  def has_critical_errors?(%__MODULE__{errors: errors}) do
    Enum.any?(errors, &Error.critical?/1)
  end

  @doc """
  Converts the validation context to a report.
  """
  @spec to_report(t()) :: Report.t()
  def to_report(%__MODULE__{} = context) do
    end_time = DateTime.utc_now()
    duration = DateTime.diff(end_time, context.start_time, :millisecond)

    %Report{
      errors: Enum.reverse(context.errors),
      warnings: Enum.reverse(context.warnings),
      validation_mode: context.mode,
      duration_ms: duration,
      validated_at: context.start_time
    }
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
end
