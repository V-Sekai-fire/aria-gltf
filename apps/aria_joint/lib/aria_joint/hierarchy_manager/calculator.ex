# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.HierarchyManager.Calculator do
  @moduledoc """
  Transform calculation logic for HierarchyManager.

  Handles global transform calculations using both functional and
  registry-based approaches for optimal performance.
  """

  alias AriaJoint.{Joint, Registry}
  alias AriaMath.{Matrix4, Matrix4.Core, Matrix4.Transformations}

  @doc """
  Calculate global transform using functional approach.

  Uses provided node lookup for parent resolution instead of Registry.

  ## Parameters

  - `joint` - Joint to calculate global transform for
  - `transforms_cache` - Cache of already calculated transforms
  - `node_lookup` - Map of node_id to Joint for parent resolution

  ## Returns

  Global transform matrix for the joint.
  """
  @spec calculate_functional(Joint.t(), %{Joint.node_id() => Matrix4.t()}, %{
          Joint.node_id() => Joint.t()
        }) :: Matrix4.t()
  def calculate_functional(joint, transforms_cache, node_lookup) do
    case joint.parent do
      nil ->
        # Root node - global transform is same as local transform
        joint.local_transform

      parent_id ->
        # Child node - multiply parent global * local transform
        case Map.get(transforms_cache, parent_id) do
          nil ->
            # Parent not cached, calculate using node lookup (functional approach)
            case Map.get(node_lookup, parent_id) do
              nil ->
                joint.local_transform

              parent_joint ->
                parent_global = calculate_functional(parent_joint, transforms_cache, node_lookup)
                Matrix4.multiply(parent_global, joint.local_transform)
            end

          parent_global ->
            # Use cached parent global transform
            result = Core.multiply(parent_global, joint.local_transform)

            # Apply orthogonalization if scale is disabled
            if joint.disable_scale do
              Transformations.orthogonalize(result)
            else
              result
            end
        end
    end
  end

  @doc """
  Calculate global transform using optimized registry approach.

  Uses transforms cache for parent resolution with Registry fallback.

  ## Parameters

  - `joint` - Joint to calculate global transform for
  - `transforms_cache` - Cache of already calculated transforms

  ## Returns

  Global transform matrix for the joint.
  """
  @spec calculate_optimized(Joint.t(), %{Joint.node_id() => Matrix4.t()}) :: Matrix4.t()
  def calculate_optimized(joint, transforms_cache) do
    case joint.parent do
      nil ->
        # Root node - global transform is same as local transform
        joint.local_transform

      parent_id ->
        # Child node - multiply parent global * local transform
        case Map.get(transforms_cache, parent_id) do
          nil ->
            # Parent not cached, calculate from registry (fallback)
            case get_joint_by_id(parent_id) do
              nil ->
                joint.local_transform

              parent_joint ->
                parent_global = Joint.get_global_transform(parent_joint)
                Matrix4.multiply(parent_global, joint.local_transform)
            end

          parent_global ->
            # Use cached parent global transform
            result = Core.multiply(parent_global, joint.local_transform)

            # Apply orthogonalization if scale is disabled
            if joint.disable_scale do
              Transformations.orthogonalize(result)
            else
              result
            end
        end
    end
  end

  @doc """
  Calculate and cache global transform for a specific joint.

  ## Parameters

  - `joint_id` - ID of joint to calculate transform for
  - `transforms_cache` - Current transforms cache

  ## Returns

  Global transform matrix for the joint.
  """
  @spec calculate_and_cache(Joint.node_id(), %{Joint.node_id() => Matrix4.t()}) :: Matrix4.t()
  def calculate_and_cache(joint_id, transforms_cache) do
    case get_joint_by_id(joint_id) do
      nil ->
        Matrix4.identity()

      joint ->
        calculate_optimized(joint, transforms_cache)
    end
  end

  # Private helper functions

  @spec get_joint_by_id(Joint.node_id()) :: Joint.t() | nil
  defp get_joint_by_id(joint_id) do
    case Registry.lookup(:joint_registry, joint_id) do
      [{_pid, joint}] -> joint
      [] -> nil
    end
  end
end
