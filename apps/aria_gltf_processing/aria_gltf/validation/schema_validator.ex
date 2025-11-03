# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.SchemaValidator do
  @moduledoc """
  JSON schema validation for glTF 2.0 documents.

  This module validates glTF documents against the official glTF 2.0 JSON schema
  to ensure structural compliance with the specification.

  Uses a hybrid approach:
  - Manual validation for critical constraints (always performed)
  - JSON schema validation via json_xema when available (complementary)
  """

  alias AriaGltf.{Document, Asset}
  alias AriaGltf.Validation.{Context, ManualValidator, JsonSchemaValidator}

  @doc """
  Validates a document against the glTF 2.0 JSON schema.

  Uses a hybrid validation approach:
  1. Manual validation (always performed) for critical constraints
  2. JSON schema validation (when available) for structural compliance

  ## Returns

  Updated context with any validation errors

  ## Examples

      context = AriaGltf.Validation.SchemaValidator.validate(context)
  """
  @spec validate(Context.t()) :: Context.t()
  def validate(%Context{document: document} = context) do
    # Convert document to JSON for schema validation
    json = Document.to_json(document)

    # Always perform manual validation (critical constraints)
    context = ManualValidator.validate(context, json)

    # Attempt JSON schema validation if available
    context = JsonSchemaValidator.validate(context, json)

    context
  end

  @doc """
  Validates specific glTF data types and constraints.
  """
  @spec validate_data_types(Context.t()) :: Context.t()
  def validate_data_types(%Context{} = context) do
    raise "TODO: Implement #{__MODULE__}.validate_data_types"
  end

  @doc """
  Validates glTF extension usage and requirements.
  """
  @spec validate_extensions(Context.t()) :: Context.t()
  def validate_extensions(%Context{document: document} = context) do
    used = document.extensions_used || []
    required = document.extensions_required || []

    # All required extensions must be in used extensions
    missing = required -- used

    Enum.reduce(missing, context, fn ext, ctx ->
      Context.add_error(
        ctx,
        :extensions,
        "Required extension '#{ext}' not declared in extensionsUsed"
      )
    end)
  end

  @doc """
  Validates accessor and buffer view relationships.
  """
  @spec validate_data_access(Context.t()) :: Context.t()
  def validate_data_access(%Context{document: document} = context) do
    accessors = document.accessors || []
    buffer_views = document.buffer_views || []
    buffers = document.buffers || []

    # Validate accessor -> buffer view -> buffer chain
    Enum.with_index(accessors)
    |> Enum.reduce(context, fn {accessor, index}, ctx ->
      validate_accessor_chain(ctx, accessor, index, buffer_views, buffers)
    end)
  end

  defp validate_accessor_chain(context, accessor, accessor_index, buffer_views, buffers) do
    case accessor do
      %{buffer_view: bv_index} when is_integer(bv_index) ->
        if bv_index >= 0 and bv_index < length(buffer_views) do
          buffer_view = Enum.at(buffer_views, bv_index)
          validate_buffer_view_chain(context, buffer_view, bv_index, buffers, accessor_index)
        else
          Context.add_error(
            context,
            {:accessor, accessor_index},
            "Invalid bufferView index: #{bv_index}"
          )
        end

      # No buffer view reference is valid for some accessors
      _ ->
        context
    end
  end

  defp validate_buffer_view_chain(context, buffer_view, bv_index, buffers, accessor_index) do
    case buffer_view do
      %{buffer: buffer_index} when is_integer(buffer_index) ->
        if buffer_index >= 0 and buffer_index < length(buffers) do
          context
        else
          Context.add_error(
            context,
            {:buffer_view, bv_index},
            "Invalid buffer index: #{buffer_index} (referenced by accessor #{accessor_index})"
          )
        end

      _ ->
        Context.add_error(
          context,
          {:buffer_view, bv_index},
          "Buffer index is required for bufferView"
        )
    end
  end
end
