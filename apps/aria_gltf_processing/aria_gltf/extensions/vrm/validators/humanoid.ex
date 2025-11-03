# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.Vrm.Validators.Humanoid do
  @moduledoc """
  VRM humanoid bone structure validation.

  Validates VRM humanoid bone mappings and ensures required bones are present.
  """

  alias AriaGltf.{Document, Validation.Context}

  @doc """
  Validates VRM humanoid bone structure.
  """
  @spec validate(Context.t(), map(), Document.t()) :: Context.t()
  def validate(context, humanoid, document) when is_map(humanoid) do
    context
    |> validate_humanoid_human_bones(humanoid, document)
    |> validate_humanoid_hips_bone_required(humanoid)
  end

  def validate(context, _, _), do: context

  # Validate humanoid humanBones structure
  defp validate_humanoid_human_bones(context, humanoid, %Document{nodes: nodes}) do
    human_bones = Map.get(humanoid, "humanBones")

    if human_bones && is_map(human_bones) do
      nodes_count = length(nodes || [])

      Enum.reduce(human_bones, context, fn {bone_name, bone_data}, ctx ->
        validate_human_bone(ctx, bone_name, bone_data, nodes_count)
      end)
    else
      Context.add_error(
        context,
        :vrm_humanoid,
        "VRM humanoid.humanBones must be an object"
      )
    end
  end

  defp validate_humanoid_human_bones(context, _, _), do: context

  # Validate individual human bone
  defp validate_human_bone(context, bone_name, bone_data, nodes_count) do
    node_index = Map.get(bone_data, "node")

    if is_integer(node_index) && node_index >= 0 && node_index < nodes_count do
      context
    else
      Context.add_error(
        context,
        :vrm_humanoid,
        "VRM humanoid.humanBones.#{bone_name}.node index #{node_index} is out of bounds (max: #{nodes_count - 1})"
      )
    end
  end

  # Validate that hips bone is required
  defp validate_humanoid_hips_bone_required(context, humanoid) do
    human_bones = Map.get(humanoid, "humanBones")

    if human_bones && Map.has_key?(human_bones, "hips") do
      context
    else
      Context.add_error(
        context,
        :vrm_humanoid,
        "VRM humanoid.humanBones.hips is required"
      )
    end
  end
end

