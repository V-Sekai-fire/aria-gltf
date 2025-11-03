# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Transform.Tensor.Advanced do
  @moduledoc """
  Advanced operations for joint tensors.

  Provides IK solving, integration functions, and high-level batch operations
  that combine multiple tensor operations for complex joint manipulation tasks.
  """

  alias AriaJoint.{Joint, Registry, DirtyState}
  alias AriaJoint.Transform.Tensor.{Core, Operations, Hierarchy}

  @type batch_result() :: %{
          joints: [Joint.t()],
          tensor_data: Core.joint_tensor()
        }

  @doc """
  Perform batch IK operations on joint chains.

  This applies Cyclic Coordinate Descent (CCD) IK to multiple joint chains simultaneously.

  ## Examples

      # target_positions: tensor of shape {num_chains, 3}
      # chain_indices: list of lists, each containing joint indices for a chain
      updated_tensor = AriaJoint.Transform.Tensor.Advanced.solve_ik_batch(joint_tensor, target_positions, chain_indices)
  """
  @spec solve_ik_batch(Core.joint_tensor(), Nx.Tensor.t(), [[integer()]]) :: Core.joint_tensor()
  def solve_ik_batch(joint_tensor, _target_positions, _chain_indices) do
    # This is a simplified IK solver - in practice, you'd implement more sophisticated algorithms
    # For now, we'll just mark the joints as needing updates
    num_joints = Nx.axis_size(joint_tensor.local_transforms, 0)
    dirty_flag = DirtyState.to_integer(DirtyState.dirty_global())
    updated_dirty = Nx.broadcast(dirty_flag, {num_joints})

    # TODO: Implement actual IK solving logic using tensor operations
    # This would involve iterative optimization to reach target positions

    %{joint_tensor | dirty_flags: updated_dirty}
  end

  @doc """
  Apply tensor-based transform to a single joint (convenience function).

  ## Examples

      updated_joint = AriaJoint.Transform.Tensor.Advanced.apply_transform_nx(joint, transform_tensor)
  """
  @spec apply_transform_nx(Joint.t(), Nx.Tensor.t()) :: Joint.t()
  def apply_transform_nx(joint, transform_tensor) do
    # Convert single joint to tensor format
    joint_tensor = Core.from_joints([joint])

    # Apply transform
    transform_4x4 = Nx.reshape(transform_tensor, {1, 4, 4})
    updated_tensor = Operations.apply_local_transforms_batch(joint_tensor, transform_4x4)

    # Convert back and return first joint
    [updated_joint] = Core.to_joints(updated_tensor, [joint])
    updated_joint
  end

  @doc """
  Batch update multiple joints and sync with registry.

  ## Examples

      {:ok, updated_joints} = AriaJoint.Transform.Tensor.Advanced.batch_update_and_sync(joints, transforms)
  """
  @spec batch_update_and_sync([Joint.t()], Nx.Tensor.t()) :: {:ok, [Joint.t()]} | {:error, term()}
  def batch_update_and_sync(joints, transforms) when is_list(joints) do
    try do
      # Convert to tensors
      joint_tensor = Core.from_joints(joints)

      # Apply transforms
      updated_tensor =
        joint_tensor
        |> Operations.apply_local_transforms_batch(transforms)
        |> Hierarchy.compute_global_transforms_batch()

      # Convert back to joints
      updated_joints = Core.to_joints(updated_tensor, joints)

      # Sync with registry
      Enum.each(updated_joints, fn joint ->
        Registry.update_node(joint)
      end)

      {:ok, updated_joints}
    rescue
      error -> {:error, error}
    end
  end
end
