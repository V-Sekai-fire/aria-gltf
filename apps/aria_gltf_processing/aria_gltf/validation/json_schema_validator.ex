# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.JsonSchemaValidator do
  @moduledoc """
  JSON schema validation for glTF 2.0 documents using json_xema.

  This module provides JSON schema validation via the json_xema library,
  which supports draft-07 JSON schemas. Note that glTF schemas use draft-2020-12,
  so there may be compatibility issues.
  """

  alias AriaGltf.Validation.{Context, SchemaLoader}

  @json_xema_available Code.ensure_loaded?(JsonXema)

  @doc """
  Validates a JSON document against the glTF 2.0 JSON schema using json_xema.

  ## Returns

  Updated context with any validation warnings (errors are treated as warnings
  due to potential draft version mismatch).
  """
  @spec validate(Context.t(), map()) :: Context.t()
  def validate(context, json) do
    if @json_xema_available do
      validate_with_json_xema(context, json)
    else
      context
    end
  end

  # Validate using JSON schema library (json_xema)
  defp validate_with_json_xema(context, json) do
    case SchemaLoader.load_gltf_schema() do
      {:ok, schema} ->
        # Attempt to validate with json_xema
        # Note: glTF schemas are draft-2020-12, json_xema supports up to draft-07
        # This may have compatibility issues, so we handle errors gracefully
        case validate_with_xema(schema, json) do
          :ok ->
            context

          {:error, errors} ->
            # JSON schema validation errors are warnings, not fatal
            # (since draft version mismatch may cause false positives)
            add_json_schema_warnings(context, errors)
        end

      {:error, _reason} ->
        # Schema loading failed, skip JSON schema validation
        context
    end
  end

  # Validate with JsonXema library
  defp validate_with_xema(schema, json) do
    try do
      xema = JsonXema.new(schema)

      case JsonXema.validate(xema, json) do
        :ok ->
          :ok

        {:error, %JsonXema.ValidationError{errors: errors}} ->
          error_messages =
            Enum.map(errors, fn error ->
              format_xema_error(error)
            end)

          {:error, error_messages}

        {:error, reason} ->
          {:error, ["JSON schema validation error: #{inspect(reason)}"]}
      end
    rescue
      e ->
        # Handle draft version incompatibility or other issues gracefully
        {:error, ["JSON schema validation unavailable: #{Exception.message(e)}"]}
    end
  end

  # Format JsonXema error for reporting
  defp format_xema_error(%{message: message, path: path}) do
    path_str = Enum.join(path, ".")
    if path_str == "" do
      message
    else
      "#{path_str}: #{message}"
    end
  end

  defp format_xema_error(error) when is_binary(error), do: error
  defp format_xema_error(error), do: inspect(error)

  # Add JSON schema validation warnings (not errors, since draft mismatch may cause issues)
  defp add_json_schema_warnings(context, warnings) do
    Enum.reduce(warnings, context, fn warning, ctx ->
      Context.add_warning(ctx, :json_schema, warning)
    end)
  end
end

