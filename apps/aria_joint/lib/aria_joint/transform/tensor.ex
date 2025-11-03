# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Transform.Tensor do
  @moduledoc """
  Tensor-based transform operations for Joint nodes using Nx.

  Provides batch operations for multiple joints, enabling efficient GPU-accelerated
  transform computations for animation and IK systems. This module complements
  the tuple-based AriaJoint.Transform with high-performance tensor operations.

  ## Features

  - Batch transform operations for multiple joints simultaneously
  - GPU-accelerated matrix computations via Nx
  - Efficient hierarchy propagation using tensor operations
  - Memory-optimized operations for large joint hierarchies
  - Seamless integration with AriaMath tensor functions

  ## Usage

      # Batch update multiple joint transforms
      joint_tensors = AriaJoint.Transform.Tensor.from_joints(joints)
      updated_tensors = AriaJoint.Transform.Tensor.apply_transforms_batch(joint_tensors, transforms)
      updated_joints = AriaJoint.Transform.Tensor.to_joints(updated_tensors, joints)

      # Batch coordinate space conversions
      global_points = AriaJoint.Transform.Tensor.to_global_batch(joints, local_points)
  """

  alias AriaJoint.Transform.Tensor.{Core, Operations, Hierarchy, Advanced}

  # Re-export types
  @type joint_tensor() :: Core.joint_tensor()
  @type batch_result() :: Advanced.batch_result()

  # Core tensor operations
  defdelegate from_joints(joints), to: Core
  defdelegate to_joints(tensor_data, original_joints), to: Core
  defdelegate extract_positions_batch(joint_tensor), to: Core
  defdelegate extract_rotations_batch(joint_tensor), to: Core

  # Transform operations
  defdelegate apply_local_transforms_batch(joint_tensor, new_transforms), to: Operations
  defdelegate apply_rotations_batch(joint_tensor, rotations), to: Operations
  defdelegate apply_scales_batch(joint_tensor, scales), to: Operations
  defdelegate interpolate_batch(tensor_a, tensor_b, t), to: Operations
  defdelegate to_local_batch(joint_tensor, global_points), to: Operations
  defdelegate to_global_batch(joint_tensor, local_points), to: Operations

  # Hierarchy operations
  defdelegate compute_global_transforms_batch(joint_tensor), to: Hierarchy

  defdelegate compute_global_transforms_constant_memory(joint_tensor, chunk_size \\ 512),
    to: Hierarchy

  # Advanced operations
  defdelegate solve_ik_batch(joint_tensor, target_positions, chain_indices), to: Advanced
  defdelegate apply_transform_nx(joint, transform_tensor), to: Advanced
  defdelegate batch_update_and_sync(joints, transforms), to: Advanced
end
