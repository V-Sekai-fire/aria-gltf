# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.Vrm.Validators.Expression do
  @moduledoc """
  VRM expression (blend shape) validation.

  Validates VRM expression presets and custom expressions.
  """

  alias AriaGltf.Validation.Context

  @doc """
  Validates VRM expressions.
  """
  @spec validate(Context.t(), map()) :: Context.t()
  def validate(context, expressions) when is_map(expressions) do
    presets = Map.get(expressions, "preset")
    custom = Map.get(expressions, "custom")

    context
    |> validate_expression_presets(presets)
    |> validate_expression_custom(custom)
  end

  def validate(context, _), do: context

  # Validate expression presets
  defp validate_expression_presets(context, presets) when is_map(presets) do
    valid_presets = [
      "happy",
      "angry",
      "sad",
      "relaxed",
      "surprised",
      "aa",
      "ih",
      "ou",
      "ee",
      "oh",
      "blink",
      "blinkLeft",
      "blinkRight",
      "lookUp",
      "lookDown",
      "lookLeft",
      "lookRight"
    ]

    Enum.reduce(presets, context, fn {preset_name, preset_data}, ctx ->
      if preset_name in valid_presets do
        validate_expression_data(ctx, preset_name, preset_data)
      else
        Context.add_warning(
          ctx,
          :vrm_expressions,
          "Unknown VRM expression preset: #{preset_name}"
        )
      end
    end)
  end

  defp validate_expression_presets(context, _), do: context

  # Validate custom expressions
  defp validate_expression_custom(context, custom) when is_map(custom) do
    Enum.reduce(custom, context, fn {custom_name, custom_data}, ctx ->
      validate_expression_data(ctx, custom_name, custom_data)
    end)
  end

  defp validate_expression_custom(context, _), do: context

  # Validate expression data structure
  defp validate_expression_data(context, expression_name, expression_data) do
    is_binary = Map.get(expression_data, "isBinary")

    if is_boolean(is_binary) do
      context
    else
      Context.add_error(
        context,
        :vrm_expressions,
        "VRM expressions.#{expression_name}.isBinary must be a boolean"
      )
    end
  end
end

