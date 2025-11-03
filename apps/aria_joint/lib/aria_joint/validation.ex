# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Validation do
  @moduledoc """
  Validation logic for Joint nodes and operations.

  Handles validation of node structures, hierarchy constraints,
  transforms, and circular dependency detection.
  """

  alias AriaMath.Matrix4

  # Robustness constants
  @max_hierarchy_depth 100
  @max_children_per_node 1000

  @type joint_error ::
          :invalid_node
          | :invalid_transform
          | :circular_dependency
          | :hierarchy_too_deep
          | :too_many_children

  @doc """
  Validate a node structure.
  """
  @spec validate_node_struct(AriaJoint.Joint.t()) :: :ok | {:error, joint_error()}
  def validate_node_struct(%AriaJoint.Joint{} = node) do
    cond do
      not is_reference(node.id) ->
        {:error, :invalid_node}

      not valid_transform?(node.local_transform) ->
        {:error, :invalid_transform}

      not valid_transform?(node.global_transform) ->
        {:error, :invalid_transform}

      true ->
        :ok
    end
  end

  def validate_node_struct(_), do: {:error, :invalid_node}

  @doc """
  Validate hierarchy constraints for a node.
  """
  @spec validate_hierarchy_constraints(AriaJoint.Joint.t()) :: :ok | {:error, joint_error()}
  def validate_hierarchy_constraints(node) do
    cond do
      calculate_hierarchy_depth(node) >= @max_hierarchy_depth ->
        {:error, :hierarchy_too_deep}

      length(node.children) >= @max_children_per_node ->
        {:error, :too_many_children}

      true ->
        :ok
    end
  end

  @doc """
  Validate transform input.
  """
  @spec validate_transform_input(Matrix4.t()) :: :ok | {:error, joint_error()}
  def validate_transform_input(transform) do
    if valid_transform?(transform) do
      :ok
    else
      {:error, :invalid_transform}
    end
  end

  @doc """
  Check if transform is valid.
  """
  @spec valid_transform?(Matrix4.t()) :: boolean()
  def valid_transform?(tensor) do
    case Nx.shape(tensor) do
      {4, 4} ->
        # Check that all elements are finite numbers
        tensor
        |> Nx.to_flat_list()
        |> Enum.all?(fn element ->
          is_number(element) and
            element != :nan and
            element != :infinity and
            element != :neg_infinity and
            abs(element) < 1.0e12
        end)

      _ ->
        false
    end
  end

  @doc """
  Validate no circular dependency would be created.
  """
  @spec validate_no_circular_dependency(AriaJoint.Joint.t(), AriaJoint.Joint.t()) ::
          :ok | {:error, joint_error()}
  def validate_no_circular_dependency(child_node, potential_parent) do
    if would_create_cycle?(child_node, potential_parent) do
      {:error, :circular_dependency}
    else
      :ok
    end
  end

  @doc """
  Check if setting parent would create a cycle.
  """
  @spec would_create_cycle?(AriaJoint.Joint.t(), AriaJoint.Joint.t()) :: boolean()
  def would_create_cycle?(child_node, potential_parent, visited \\ MapSet.new()) do
    cond do
      child_node.id == potential_parent.id ->
        true

      MapSet.member?(visited, potential_parent.id) ->
        # Already visited, no cycle through this path
        false

      true ->
        new_visited = MapSet.put(visited, potential_parent.id)

        case get_parent_node(potential_parent) do
          nil -> false
          ancestor -> would_create_cycle?(child_node, ancestor, new_visited)
        end
    end
  end

  @doc """
  Calculate hierarchy depth for a node.
  """
  @spec calculate_hierarchy_depth(AriaJoint.Joint.t(), non_neg_integer()) :: non_neg_integer()
  def calculate_hierarchy_depth(node, current_depth \\ 0) do
    if current_depth >= @max_hierarchy_depth do
      @max_hierarchy_depth
    else
      case get_parent_node(node) do
        nil -> current_depth
        parent -> calculate_hierarchy_depth(parent, current_depth + 1)
      end
    end
  end

  # Private helper to get parent node
  @spec get_parent_node(AriaJoint.Joint.t()) :: AriaJoint.Joint.t() | nil
  defp get_parent_node(node) do
    case node.parent do
      nil -> nil
      parent_id -> AriaJoint.Registry.get_node_by_id(parent_id)
    end
  end
end
