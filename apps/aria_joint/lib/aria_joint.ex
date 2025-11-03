# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint do
  @moduledoc """
  Transform hierarchy management for EWBIK bone chains.

  AriaJoint provides efficient transform hierarchy management with parent-child
  relationships, dirty state tracking, and coordinate space conversions. This is
  a port of the IKNode3D class from the many_bone_ik project.

  ## Features

  - Local and global transform caching with dirty state optimization
  - Parent-child bone hierarchy management
  - Coordinate space conversions (local ↔ global)
  - Transform propagation throughout hierarchy
  - Scale management (can disable scale for pure rotational joints)
  - Efficient updates only when transforms are dirty

  ## Usage

      # Create root bone
      {:ok, root} = AriaJoint.new()

      # Create child bone with parent relationship
      {:ok, child} = AriaJoint.new(parent: root)

      # Set local transform
      child = AriaJoint.set_transform(child, transform)

      # Get global transform (automatically computed from hierarchy)
      global_transform = AriaJoint.get_global_transform(child)

  ## Transform Hierarchy

  Each Joint maintains:
  - **Local Transform**: Transform relative to parent bone
  - **Global Transform**: Absolute transform in world space (computed from hierarchy)
  - **Dirty State**: Tracks what needs recomputation for efficiency

  When a bone's transform changes, dirty flags propagate to children automatically.

  ## Coordinate Space Conversions

      # Convert point from world space to local bone space
      local_point = AriaJoint.to_local(bone, world_point)

      # Convert point from local bone space to world space
      world_point = AriaJoint.to_global(bone, local_point)
  """

  alias AriaJoint.{Joint}

  @doc """
  Create a new Joint with optional parent relationship.

  ## Options

  - `:parent` - Parent Joint to attach to (creates parent-child relationship)
  - `:disable_scale` - Whether to disable scale propagation (default: false)

  ## Examples

      # Create root node
      {:ok, root} = AriaJoint.new()

      # Create child node
      {:ok, child} = AriaJoint.new(parent: root)

      # Create node with scale disabled
      {:ok, joint} = AriaJoint.new(disable_scale: true)

  ## Returns

  `{:ok, node}` on success, `{:error, reason}` on failure.
  """
  defdelegate new(opts \\ []), to: Joint

  @doc """
  Set the local transform of a node.

  Updates the local transform and marks appropriate dirty states for efficient
  recomputation of global transforms.

  ## Examples

      transform = AriaMath.Matrix4.translation({0.5, 1.0, 0.0})
      node = AriaJoint.set_transform(node, transform)
  """
  defdelegate set_transform(node, transform), to: Joint

  @doc """
  Set the global transform of a node.

  Automatically computes the appropriate local transform based on parent hierarchy.

  ## Examples

      global_transform = AriaMath.Matrix4.translation({1.0, 2.0, 3.0})
      node = AriaJoint.set_global_transform(node, global_transform)
  """
  defdelegate set_global_transform(node, global_transform), to: Joint

  @doc """
  Get the local transform of a node.

  Updates local transform from rotation and scale if dirty.

  ## Examples

      local_transform = AriaJoint.get_transform(node)
  """
  defdelegate get_transform(node), to: Joint

  @doc """
  Get the global transform of a node.

  Computes global transform from hierarchy if dirty, with efficient caching.

  ## Examples

      global_transform = AriaJoint.get_global_transform(node)
  """
  defdelegate get_global_transform(node), to: Joint

  @doc """
  Set parent-child relationship between nodes.

  Automatically manages bidirectional parent-child relationships and propagates
  transform changes.

  ## Examples

      child = AriaJoint.set_parent(child, parent)
  """
  defdelegate set_parent(node, parent), to: Joint

  @doc """
  Get the parent node of a node.

  ## Examples

      parent = AriaJoint.get_parent(node)

  Returns `nil` if node has no parent.
  """
  defdelegate get_parent(node), to: Joint

  @doc """
  Convert a point from global space to local node space.

  ## Examples

      global_point = {1.0, 2.0, 3.0}
      local_point = AriaJoint.to_local(node, global_point)
  """
  defdelegate to_local(node, global_point), to: Joint

  @doc """
  Convert a point from local node space to global space.

  ## Examples

      local_point = {0.5, 0.0, 0.0}
      global_point = AriaJoint.to_global(node, local_point)
  """
  defdelegate to_global(node, local_point), to: Joint

  @doc """
  Rotate node locally using global basis.

  ## Parameters

  - `node` - The node to rotate
  - `basis` - Global rotation basis to apply
  - `propagate` - Whether to propagate changes to children (default: false)

  ## Examples

      rotation_basis = AriaMath.Matrix4.rotation_y(Math.pi / 4)
      node = AriaJoint.rotate_local_with_global(node, rotation_basis, true)
  """
  defdelegate rotate_local_with_global(node, basis, propagate \\ false), to: Joint

  @doc """
  Enable or disable scale propagation for this node.

  When scale is disabled, the node will orthogonalize its global transform
  to remove scaling effects.

  ## Examples

      node = AriaJoint.set_disable_scale(node, true)
  """
  defdelegate set_disable_scale(node, disable_scale), to: Joint

  @doc """
  Check if scale is disabled for this node.

  ## Examples

      is_disabled = AriaJoint.scale_disabled?(node)
  """
  defdelegate scale_disabled?(node), to: Joint

  @doc """
  Clean up node and remove from hierarchy.

  Removes all parent-child relationships and cleans up registry entries.

  ## Examples

      AriaJoint.cleanup(node)
  """
  defdelegate cleanup(node), to: Joint

  # Nx tensor integration functions

  @doc """
  Convert a list of joints to tensor format for batch operations.

  ## Examples

      joint_tensors = AriaJoint.from_joints_nx([joint1, joint2, joint3])
      {num_joints, 4, 4} = Nx.shape(joint_tensors.local_transforms)
  """
  @spec from_joints_nx([Joint.t()]) :: AriaJoint.Transform.Tensor.joint_tensor()
  def from_joints_nx(joints), do: AriaJoint.Transform.Tensor.from_joints(joints)

  @doc """
  Convert tensor data back to updated joint list.

  ## Examples

      updated_joints = AriaJoint.to_joints_nx(tensor_data, original_joints)
  """
  @spec to_joints_nx(AriaJoint.Transform.Tensor.joint_tensor(), [Joint.t()]) :: [Joint.t()]
  def to_joints_nx(tensor_data, original_joints),
    do: AriaJoint.Transform.Tensor.to_joints(tensor_data, original_joints)

  @doc """
  Apply local transforms to multiple joints using batch tensor operations.

  ## Examples

      # transforms is a tensor of shape {num_joints, 4, 4}
      updated_tensor = AriaJoint.apply_local_transforms_batch_nx(joint_tensor, transforms)
  """
  @spec apply_local_transforms_batch_nx(AriaJoint.Transform.Tensor.joint_tensor(), Nx.Tensor.t()) ::
          AriaJoint.Transform.Tensor.joint_tensor()
  def apply_local_transforms_batch_nx(joint_tensor, transforms),
    do: AriaJoint.Transform.Tensor.apply_local_transforms_batch(joint_tensor, transforms)

  @doc """
  Compute global transforms for all joints using batch operations.

  ## Examples

      updated_tensor = AriaJoint.compute_global_transforms_batch_nx(joint_tensor)
  """
  @spec compute_global_transforms_batch_nx(AriaJoint.Transform.Tensor.joint_tensor()) ::
          AriaJoint.Transform.Tensor.joint_tensor()
  def compute_global_transforms_batch_nx(joint_tensor),
    do: AriaJoint.Transform.Tensor.compute_global_transforms_batch(joint_tensor)

  @doc """
  Convert multiple points from local to global space for multiple joints.

  ## Examples

      global_points = AriaJoint.to_global_batch_nx(joint_tensor, local_points)

      FIXME: Implement to_global_batch
  """
  @spec to_global_batch_nx(AriaJoint.Transform.Tensor.joint_tensor(), Nx.Tensor.t()) ::
          Nx.Tensor.t()
  def to_global_batch_nx(joint_tensor, local_points),
    do: AriaJoint.Transform.Tensor.to_global_batch(joint_tensor, local_points)

  @doc """
  Convert multiple points from global to local space for multiple joints.

  ## Examples

      local_points = AriaJoint.to_local_batch_nx(joint_tensor, global_points)
  """
  @spec to_local_batch_nx(AriaJoint.Transform.Tensor.joint_tensor(), Nx.Tensor.t()) ::
          Nx.Tensor.t()
  def to_local_batch_nx(joint_tensor, global_points),
    do: AriaJoint.Transform.Tensor.to_local_batch(joint_tensor, global_points)

  @doc """
  Apply rotations to multiple joints using batch operations.

  ## Examples

      updated_tensor = AriaJoint.apply_rotations_batch_nx(joint_tensor, rotations)
  """
  @spec apply_rotations_batch_nx(AriaJoint.Transform.Tensor.joint_tensor(), Nx.Tensor.t()) ::
          AriaJoint.Transform.Tensor.joint_tensor()
  def apply_rotations_batch_nx(joint_tensor, rotations),
    do: AriaJoint.Transform.Tensor.apply_rotations_batch(joint_tensor, rotations)

  @doc """
  Apply scaling to multiple joints using batch operations.

  ## Examples

      updated_tensor = AriaJoint.apply_scales_batch_nx(joint_tensor, scales)
  """
  @spec apply_scales_batch_nx(AriaJoint.Transform.Tensor.joint_tensor(), Nx.Tensor.t()) ::
          AriaJoint.Transform.Tensor.joint_tensor()
  def apply_scales_batch_nx(joint_tensor, scales),
    do: AriaJoint.Transform.Tensor.apply_scales_batch(joint_tensor, scales)

  @doc """
  Interpolate between two sets of joint transforms for animation.

  ## Examples

      interpolated = AriaJoint.interpolate_batch_nx(joint_tensor_a, joint_tensor_b, 0.5)
  """
  @spec interpolate_batch_nx(
          AriaJoint.Transform.Tensor.joint_tensor(),
          AriaJoint.Transform.Tensor.joint_tensor(),
          float()
        ) :: AriaJoint.Transform.Tensor.joint_tensor()
  def interpolate_batch_nx(tensor_a, tensor_b, t),
    do: AriaJoint.Transform.Tensor.interpolate_batch(tensor_a, tensor_b, t)

  @doc """
  Extract joint positions from transform matrices.

  ## Examples

      positions = AriaJoint.extract_positions_batch_nx(joint_tensor)
  """
  @spec extract_positions_batch_nx(AriaJoint.Transform.Tensor.joint_tensor()) :: Nx.Tensor.t()
  def extract_positions_batch_nx(joint_tensor),
    do: AriaJoint.Transform.Tensor.extract_positions_batch(joint_tensor)

  @doc """
  Extract joint rotations as quaternions from transform matrices.

  ## Examples

      quaternions = AriaJoint.extract_rotations_batch_nx(joint_tensor)
  """
  @spec extract_rotations_batch_nx(AriaJoint.Transform.Tensor.joint_tensor()) :: Nx.Tensor.t()
  def extract_rotations_batch_nx(joint_tensor),
    do: AriaJoint.Transform.Tensor.extract_rotations_batch(joint_tensor)

  @doc """
  Apply tensor-based transform to a single joint (convenience function).

  ## Examples

      updated_joint = AriaJoint.apply_transform_nx(joint, transform_tensor)
  """
  @spec apply_transform_nx(Joint.t(), Nx.Tensor.t()) :: Joint.t()
  def apply_transform_nx(joint, transform_tensor),
    do: AriaJoint.Transform.Tensor.apply_transform_nx(joint, transform_tensor)

  @doc """
  Batch update multiple joints and sync with registry.

  ## Examples

      {:ok, updated_joints} = AriaJoint.batch_update_and_sync_nx(joints, transforms)
  """
  @spec batch_update_and_sync_nx([Joint.t()], Nx.Tensor.t()) ::
          {:ok, [Joint.t()]} | {:error, term()}
  def batch_update_and_sync_nx(joints, transforms),
    do: AriaJoint.Transform.Tensor.batch_update_and_sync(joints, transforms)
end
