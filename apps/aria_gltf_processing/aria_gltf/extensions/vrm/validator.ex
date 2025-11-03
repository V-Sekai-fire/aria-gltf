# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.Vrm.Validator do
  @moduledoc """
  Validation for VRM 1.0 extension (VRMC_vrm).

  Validates VRM 1.0 specification compliance including:
  - Meta information (title, author, contact, etc.)
  - Humanoid bone structure and mappings
  - Expressions (blend shapes)
  - Collision detection (spring bone colliders)
  - VRM-specific constraints and requirements

  Reference: VRM 1.0 Specification
  https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_vrm-1.0
  """

  alias AriaGltf.Document
  alias AriaGltf.Validation.Context
  alias AriaGltf.Extensions.Vrm.Validators.{Meta, Humanoid, Expression, Collider}

  @vrm_extension_name "VRMC_vrm"

  @doc """
  Validates VRM 1.0 extension data in a glTF document.

  ## Parameters

  - `context`: Validation context containing the document

  ## Returns

  Updated context with VRM validation errors/warnings

  ## Examples

      context = AriaGltf.Extensions.Vrm.Validator.validate(context)
  """
  @spec validate(Context.t()) :: Context.t()
  def validate(%Context{document: document} = context) do
    # Check if VRM extension is used
    extensions_used = document.extensions_used || []

    if @vrm_extension_name in extensions_used do
      context
      |> validate_vrm_extension_present(document)
      |> validate_vrm_meta(document)
      |> validate_vrm_humanoid(document)
      |> validate_vrm_expressions(document)
      |> validate_vrm_colliders(document)
    else
      context
    end
  end

  # Validate that VRM extension is present in document extensions
  defp validate_vrm_extension_present(context, %Document{extensions: extensions}) do
    if extensions && Map.has_key?(extensions, @vrm_extension_name) do
      context
    else
      Context.add_error(
        context,
        :vrm_extension,
        "VRMC_vrm extension declared in extensionsUsed but not found in extensions"
      )
    end
  end

  defp validate_vrm_extension_present(context, _), do: context

  # Validate VRM meta information
  defp validate_vrm_meta(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      meta = Map.get(vrm_ext, "meta")

      if meta do
        Meta.validate(context, meta, context.document)
      else
        Context.add_warning(
          context,
          :vrm_meta,
          "VRM extension found but meta field is missing (optional but recommended)"
        )
      end
    else
      context
    end
  end

  defp validate_vrm_meta(context, _), do: context

  # Validate VRM humanoid bone structure
  defp validate_vrm_humanoid(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      humanoid = Map.get(vrm_ext, "humanoid")

      if humanoid do
        Humanoid.validate(context, humanoid, context.document)
      else
        Context.add_warning(
          context,
          :vrm_humanoid,
          "VRM humanoid field is missing (required for VRM compliance)"
        )
      end
    else
      context
    end
  end

  defp validate_vrm_humanoid(context, _), do: context

  # Validate VRM expressions (blend shapes)
  defp validate_vrm_expressions(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      expressions = Map.get(vrm_ext, "expressions")

      if expressions && is_map(expressions) do
        Expression.validate(context, expressions)
      else
        context
      end
    else
      context
    end
  end

  defp validate_vrm_expressions(context, _), do: context

  # Validate VRM colliders (spring bone colliders)
  defp validate_vrm_colliders(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      spring_bone = Map.get(vrm_ext, "springBone")

      if spring_bone do
        Collider.validate(context, spring_bone, context.document)
      else
        context
      end
    else
      context
    end
  end

  defp validate_vrm_colliders(context, _), do: context

  # Helper: Get VRM extension from document extensions
  defp get_vrm_extension(nil), do: nil
  defp get_vrm_extension(extensions), do: Map.get(extensions, @vrm_extension_name)
end

