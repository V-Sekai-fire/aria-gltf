# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaEwbik.Segmentation do
  @moduledoc """
  Skeleton segmentation system for EWBIK solver.

  This module analyzes bone hierarchies and creates processing chains for
  efficient inverse kinematics solving using AriaJoint integration.
  """

  @doc """
  Analyze skeleton and create effector chains for IK solving.

  ## Parameters
  - `skeleton`: Map of joint data from AriaJoint
  - `effector_targets`: List of {joint_id, target_position} tuples

  ## Returns
  - `{:ok, chains}`: List of processing chains for each effector
  - `{:error, reason}`: If analysis fails
  """
  def analyze_chains(skeleton, effector_targets) do
    try do
      chains =
        Enum.map(effector_targets, fn {effector_id, _target} ->
          case build_chain(skeleton, effector_id) do
            [] ->
              # Invalid effector - return error for this chain
              {:error, "No valid chain found for effector #{effector_id}"}

            chain ->
              chain
          end
        end)

      # Check if any chains failed
      errors =
        Enum.filter(chains, fn
          {:error, _} -> true
          _ -> false
        end)

      if Enum.empty?(errors) do
        {:ok, chains}
      else
        # Return the first error found with proper prefix
        error_msg = elem(hd(errors), 1)
        {:error, "Chain analysis failed: #{error_msg}"}
      end
    rescue
      error -> {:error, "Chain analysis failed: #{inspect(error)}"}
    end
  end

  @doc """
  Build a processing chain from effector to root.

  ## Parameters
  - `skeleton`: Joint hierarchy data
  - `effector_id`: ID of the end effector joint

  ## Returns
  - Chain data structure for IK processing, or empty list if invalid
  """
  def build_chain(skeleton, effector_id) do
    # Check if effector exists in skeleton
    case Map.has_key?(skeleton, effector_id) do
      false ->
        # Invalid effector - return empty chain
        []

      true ->
        # Build chain from effector to root using AriaJoint hierarchy
        build_chain_recursive(skeleton, effector_id, [])
    end
  end

  @doc """
  Get processing order for multiple chains.

  ## Parameters
  - `chains`: List of effector chains

  ## Returns
  - Ordered list of joint IDs for processing
  """
  def get_processing_order(chains) do
    # Flatten and deduplicate joint IDs
    # Order by dependency (roots first, then children)
    all_joints =
      chains
      |> Enum.flat_map(& &1)
      |> Enum.uniq()

    # For now, return in reverse order (roots to leaves)
    # TODO: Implement proper topological sorting
    Enum.reverse(all_joints)
  end

  # Private functions

  defp build_chain_recursive(_skeleton, nil, chain), do: Enum.reverse(chain)

  defp build_chain_recursive(skeleton, joint_id, chain) do
    # TODO: Use AriaJoint API to get parent
    # For now, assume we have parent information in skeleton
    parent_id = get_parent_id(skeleton, joint_id)

    build_chain_recursive(skeleton, parent_id, [joint_id | chain])
  end

  defp get_parent_id(skeleton, joint_id) do
    # TODO: Replace with actual AriaJoint.HierarchyManager call
    # This is a placeholder implementation
    case Map.get(skeleton, joint_id) do
      %{parent: parent} -> parent
      _ -> nil
    end
  end
end
