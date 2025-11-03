# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaEwbik.Propagation do
  @moduledoc """
  Motion propagation management for EWBIK solver.

  This module handles hierarchical influence distribution and motion
  propagation factors for multi-effector coordination.
  """

  @doc """
  Calculate motion propagation factors for a chain.

  ## Parameters
  - `chain`: List of joint IDs from effector to root (effector first)
  - `effector_influence`: Base influence factor for the effector

  ## Returns
  - Map of {joint_id => propagation_factor}
  """
  def calculate_propagation_factors(chain, effector_influence) do
    # Calculate propagation factors based on distance from effector
    # Chain is ordered from effector to root, so first element is closest to effector
    Enum.with_index(chain)
    |> Enum.map(fn {joint_id, index} ->
      # Closer to effector (lower index) = higher influence
      factor = effector_influence * propagation_decay_factor(index)
      {joint_id, factor}
    end)
    |> Map.new()
  end

  @doc """
  Apply motion propagation to solution adjustments.

  ## Parameters
  - `adjustments`: Raw joint adjustments from IK solver
  - `propagation_factors`: Propagation factors map
  - `hierarchy`: Joint hierarchy information

  ## Returns
  - Propagated adjustments considering hierarchical influence
  """
  def apply_propagation(adjustments, propagation_factors, hierarchy) do
    # Apply propagation factors to raw adjustments
    Enum.map(adjustments, fn {joint_id, raw_adjustment} ->
      factor = Map.get(propagation_factors, joint_id, 1.0)
      propagated_adjustment = scale_adjustment(raw_adjustment, factor)

      # Apply hierarchical weighting
      hierarchical_weight = get_hierarchical_weight(hierarchy, joint_id)
      final_adjustment = scale_adjustment(propagated_adjustment, hierarchical_weight)

      {joint_id, final_adjustment}
    end)
  end

  @doc """
  Combine solutions from multiple effectors.

  ## Parameters
  - `solutions`: List of {effector_id, adjustments} tuples
  - `hierarchy`: Joint hierarchy for conflict resolution

  ## Returns
  - Combined solution with resolved conflicts
  """
  def combine_multi_effector_solutions(solutions, hierarchy) do
    # Group adjustments by joint
    joint_adjustments = group_adjustments_by_joint(solutions)

    # Resolve conflicts for joints affected by multiple effectors
    Enum.map(joint_adjustments, fn {joint_id, adjustments} ->
      combined_adjustment = resolve_adjustment_conflicts(adjustments, hierarchy, joint_id)
      {joint_id, combined_adjustment}
    end)
    |> Map.new()
  end

  @doc """
  Calculate ultimate vs intermediary effector weights.

  ## Parameters
  - `effector_type`: :ultimate or :intermediary
  - `base_weight`: Base weight value

  ## Returns
  - Adjusted weight based on effector type
  """
  def effector_type_weight(:ultimate, base_weight), do: base_weight * 1.2
  def effector_type_weight(:intermediary, base_weight), do: base_weight * 0.8
  def effector_type_weight(_, base_weight), do: base_weight

  # Private functions

  defp propagation_decay_factor(distance) do
    # Exponential decay: closer joints have higher influence
    :math.pow(0.8, distance)
  end

  defp scale_adjustment(adjustment, _factor) do
    # TODO: Scale adjustment based on factor
    # This depends on adjustment format (rotation, translation, etc.)
    adjustment
  end

  defp get_hierarchical_weight(_hierarchy, _joint_id) do
    # TODO: Calculate weight based on joint's position in hierarchy
    # Root joints might have different weights than leaf joints
    1.0
  end

  defp group_adjustments_by_joint(solutions) do
    # Flatten all adjustments and group by joint
    Enum.flat_map(solutions, fn {_effector_id, adjustments} -> adjustments end)
    |> Enum.group_by(fn {joint_id, _adjustment} -> joint_id end)
  end

  defp resolve_adjustment_conflicts(adjustments, hierarchy, joint_id) do
    case length(adjustments) do
      1 ->
        # Single adjustment, use as-is
        [{_joint_id, adjustment}] = adjustments
        adjustment

      _multiple ->
        # Multiple adjustments, need to resolve conflict
        resolve_multiple_adjustments(adjustments, hierarchy, joint_id)
    end
  end

  defp resolve_multiple_adjustments(adjustments, _hierarchy, joint_id) do
    # TODO: Implement conflict resolution strategy
    # Options:
    # 1. Weighted average based on effector priorities
    # 2. Priority-based selection
    # 3. Hierarchical weighting

    # Placeholder: return first adjustment
    [{^joint_id, first_adjustment} | _rest] = adjustments
    first_adjustment
  end

  @doc """
  Create motion propagation configuration.

  ## Parameters
  - `effector_id`: ID of the effector
  - `influence`: Base influence factor
  - `decay_rate`: Propagation decay rate (0.0 to 1.0)

  ## Returns
  - Propagation configuration map
  """
  def create_propagation_config(effector_id, influence, decay_rate \\ 0.8) do
    %{
      effector_id: effector_id,
      base_influence: influence,
      decay_rate: decay_rate,
      type: :propagation
    }
  end

  @doc """
  Calculate ancestor-descendant weight distribution.

  ## Parameters
  - `hierarchy`: Joint hierarchy
  - `joint_id`: Joint to calculate weights for
  - `max_depth`: Maximum hierarchy depth to consider

  ## Returns
  - Map of {ancestor_id => weight}
  """
  def calculate_ancestor_weights(_hierarchy, _joint_id, _max_depth \\ 5) do
    # TODO: Traverse up the hierarchy and calculate ancestor influence weights
    # Closer ancestors have higher weights
    %{}
  end

  @doc """
  Apply temporal smoothing to motion propagation.

  ## Parameters
  - `current_propagation`: Current propagation factors
  - `previous_propagation`: Previous frame's propagation factors
  - `smoothing_factor`: Smoothing factor (0.0 to 1.0)

  ## Returns
  - Smoothed propagation factors
  """
  def smooth_propagation(current_propagation, previous_propagation, smoothing_factor) do
    # Interpolate between current and previous propagation
    Enum.map(current_propagation, fn {joint_id, current_factor} ->
      previous_factor = Map.get(previous_propagation, joint_id, current_factor)
      smoothed_factor = lerp(previous_factor, current_factor, smoothing_factor)
      {joint_id, smoothed_factor}
    end)
    |> Map.new()
  end

  defp lerp(a, b, t) do
    a + (b - a) * t
  end
end
