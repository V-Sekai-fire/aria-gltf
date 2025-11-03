# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Transform.Tensor.Operations do
  @moduledoc """
  Transform operations for joint tensors.

  Provides batch operations for applying transforms, rotations, scaling, and
  interpolation to multiple joints simultaneously using tensor operations.
  """

  alias AriaMath.Matrix4
  alias AriaJoint.{DirtyState}
  alias AriaJoint.Transform.Tensor.Core

  @doc """
  Apply local transforms to multiple joints using batch tensor operations.

  ## Examples

      # transforms is a tensor of shape {num_joints, 4, 4}
      updated_tensor = AriaJoint.Transform.Tensor.Operations.apply_local_transforms_batch(joint_tensor, transforms)
  """
  @spec apply_local_transforms_batch(Core.joint_tensor(), Nx.Tensor.t()) :: Core.joint_tensor()
  def apply_local_transforms_batch(joint_tensor, new_transforms) do
    # Update local transforms
    updated_local = new_transforms

    # Mark all joints as dirty for global transform recomputation
    num_joints = Nx.axis_size(joint_tensor.local_transforms, 0)
    dirty_global_flag = DirtyState.to_integer(DirtyState.dirty_global())
    updated_dirty = Nx.broadcast(dirty_global_flag, {num_joints})

    %{joint_tensor | local_transforms: updated_local, dirty_flags: updated_dirty}
  end

  @doc """
  Apply rotations to multiple joints using batch operations.

  ## Examples

      # rotations: tensor of shape {num_joints, 4, 4} (rotation matrices)
      updated_tensor = AriaJoint.Transform.Tensor.Operations.apply_rotations_batch(joint_tensor, rotations)
  """
  @spec apply_rotations_batch(Core.joint_tensor(), Nx.Tensor.t()) :: Core.joint_tensor()
  def apply_rotations_batch(joint_tensor, rotations) do
    # Apply rotations to local transforms
    updated_local = Matrix4.Tensor.multiply_batch(joint_tensor.local_transforms, rotations)

    # Mark as dirty for global transform recomputation
    num_joints = Nx.axis_size(joint_tensor.local_transforms, 0)
    dirty_global_flag = DirtyState.to_integer(DirtyState.dirty_global())
    updated_dirty = Nx.broadcast(dirty_global_flag, {num_joints})

    %{joint_tensor | local_transforms: updated_local, dirty_flags: updated_dirty}
  end

  @doc """
  Apply scaling to multiple joints using batch operations.

  ## Examples

      # scales: tensor of shape {num_joints, 3} (x, y, z scale factors)
      updated_tensor = AriaJoint.Transform.Tensor.Operations.apply_scales_batch(joint_tensor, scales)
  """
  @spec apply_scales_batch(Core.joint_tensor(), Nx.Tensor.t()) :: Core.joint_tensor()
  def apply_scales_batch(joint_tensor, scales) do
    # Create scaling matrices from scale vectors
    scale_matrices = Matrix4.Tensor.scaling_batch(scales)

    # Apply scaling to local transforms
    updated_local = Matrix4.Tensor.multiply_batch(joint_tensor.local_transforms, scale_matrices)

    # Mark as dirty for global transform recomputation
    num_joints = Nx.axis_size(joint_tensor.local_transforms, 0)
    dirty_global_flag = DirtyState.to_integer(DirtyState.dirty_global())
    updated_dirty = Nx.broadcast(dirty_global_flag, {num_joints})

    %{joint_tensor | local_transforms: updated_local, dirty_flags: updated_dirty}
  end

  @doc """
  Interpolate between two sets of joint transforms for animation.

  ## Examples

      # t: interpolation factor (0.0 to 1.0)
      interpolated = AriaJoint.Transform.Tensor.Operations.interpolate_batch(joint_tensor_a, joint_tensor_b, 0.5)
  """
  @spec interpolate_batch(Core.joint_tensor(), Core.joint_tensor(), float()) ::
          Core.joint_tensor()
  def interpolate_batch(tensor_a, tensor_b, t) when is_float(t) and t >= 0.0 and t <= 1.0 do
    # Interpolate local transforms using matrix interpolation
    interpolated_local =
      Matrix4.Tensor.lerp_batch(tensor_a.local_transforms, tensor_b.local_transforms, t)

    # Mark as dirty for global transform recomputation
    num_joints = Nx.axis_size(tensor_a.local_transforms, 0)
    dirty_global_flag = DirtyState.to_integer(DirtyState.dirty_global())
    updated_dirty = Nx.broadcast(dirty_global_flag, {num_joints})

    %{tensor_a | local_transforms: interpolated_local, dirty_flags: updated_dirty}
  end

  @doc """
  Convert multiple points from global to local space for multiple joints.

  ## Examples

      # global_points: tensor of shape {num_joints, 3} or {num_joints, num_points, 3}
      local_points = AriaJoint.Transform.Tensor.Operations.to_local_batch(joint_tensor, global_points)
  """
  @spec to_local_batch(Core.joint_tensor(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def to_local_batch(joint_tensor, global_points) do
    # Compute inverse transforms for all joints
    inverse_transforms = Matrix4.Tensor.inverse_batch(joint_tensor.global_transforms)
    Matrix4.Tensor.transform_points_batch(inverse_transforms, global_points)
  end

  @doc """
  Convert multiple points from local to global space for multiple joints.

  ## Examples

      # local_points: tensor of shape {num_joints, 3} or {num_joints, num_points, 3}
      global_points = AriaJoint.Transform.Tensor.Operations.to_global_batch(joint_tensor, local_points)
  """
  @spec to_global_batch(Core.joint_tensor(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def to_global_batch(joint_tensor, local_points) do
    Matrix4.Tensor.transform_points_batch(joint_tensor.global_transforms, local_points)
  end
end
