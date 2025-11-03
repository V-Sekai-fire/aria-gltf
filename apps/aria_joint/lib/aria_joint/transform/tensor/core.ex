# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Transform.Tensor.Core do
  @moduledoc """
  Core tensor operations for joint transforms.

  Handles conversion between joint lists and tensor format, providing the foundation
  for batch tensor operations on joint hierarchies.
  """

  alias AriaMath.Matrix4
  alias AriaJoint.{Joint, DirtyState}

  @type joint_tensor() :: %{
          ids: Nx.Tensor.t(),
          local_transforms: Nx.Tensor.t(),
          global_transforms: Nx.Tensor.t(),
          parent_indices: Nx.Tensor.t(),
          dirty_flags: Nx.Tensor.t()
        }

  @doc """
  Convert a list of joints to tensor format for batch operations.

  ## Examples

      joint_tensors = AriaJoint.Transform.Tensor.Core.from_joints([joint1, joint2, joint3])
      {num_joints, 4, 4} = Nx.shape(joint_tensors.local_transforms)
  """
  @spec from_joints([Joint.t()]) :: joint_tensor()
  def from_joints(joints) when is_list(joints) do
    num_joints = length(joints)

    # Extract transforms as tensor data
    local_transforms =
      joints
      |> Enum.map(fn joint -> Matrix4.to_tuple_list(joint.local_transform) end)
      |> Nx.tensor(type: :f32)
      |> Nx.reshape({num_joints, 4, 4})

    global_transforms =
      joints
      |> Enum.map(fn joint -> Matrix4.to_tuple_list(joint.global_transform) end)
      |> Nx.tensor(type: :f32)
      |> Nx.reshape({num_joints, 4, 4})

    # Create ID mapping for parent relationships
    joint_id_to_index =
      joints
      |> Enum.with_index()
      |> Map.new(fn {joint, index} -> {joint.id, index} end)

    parent_indices =
      joints
      |> Enum.map(fn joint ->
        case joint.parent do
          # Use -1 to indicate no parent
          nil -> -1
          parent_id -> Map.get(joint_id_to_index, parent_id, -1)
        end
      end)
      |> Nx.tensor(type: :s32)

    # Extract dirty flags as bit flags
    dirty_flags =
      joints
      |> Enum.map(fn joint -> DirtyState.to_integer(joint.dirty) end)
      |> Nx.tensor(type: :u8)

    # Store joint IDs for mapping back
    ids =
      joints
      |> Enum.map(fn joint ->
        :erlang.ref_to_list(joint.id) |> :erlang.list_to_binary() |> Base.encode64()
      end)
      |> Nx.tensor(type: :binary)

    %{
      ids: ids,
      local_transforms: local_transforms,
      global_transforms: global_transforms,
      parent_indices: parent_indices,
      dirty_flags: dirty_flags
    }
  end

  @doc """
  Convert tensor data back to updated joint list.

  ## Examples

      updated_joints = AriaJoint.Transform.Tensor.Core.to_joints(tensor_data, original_joints)
  """
  @spec to_joints(joint_tensor(), [Joint.t()]) :: [Joint.t()]
  def to_joints(tensor_data, original_joints) do
    local_transforms_list =
      tensor_data.local_transforms
      |> Nx.to_list()

    global_transforms_list =
      tensor_data.global_transforms
      |> Nx.to_list()

    dirty_flags_list =
      tensor_data.dirty_flags
      |> Nx.to_list()

    original_joints
    |> Enum.zip([local_transforms_list, global_transforms_list, dirty_flags_list])
    |> Enum.map(fn {joint, {local_matrix, global_matrix, dirty_int}} ->
      local_transform = Matrix4.from_tuple_list(local_matrix)
      global_transform = Matrix4.from_tuple_list(global_matrix)
      dirty_state = DirtyState.from_integer(dirty_int)

      %{
        joint
        | local_transform: local_transform,
          global_transform: global_transform,
          dirty: dirty_state
      }
    end)
  end

  @doc """
  Extract joint positions from transform matrices.

  ## Examples

      positions = AriaJoint.Transform.Tensor.Core.extract_positions_batch(joint_tensor)
      # Returns tensor of shape {num_joints, 3}
  """
  @spec extract_positions_batch(joint_tensor()) :: Nx.Tensor.t()
  def extract_positions_batch(joint_tensor) do
    Matrix4.Tensor.extract_translations_batch(joint_tensor.global_transforms)
  end

  @doc """
  Extract joint rotations as quaternions from transform matrices.

  ## Examples

      quaternions = AriaJoint.Transform.Tensor.Core.extract_rotations_batch(joint_tensor)
      # Returns tensor of shape {num_joints, 4} (w, x, y, z)
  """
  @spec extract_rotations_batch(joint_tensor()) :: Nx.Tensor.t()
  def extract_rotations_batch(joint_tensor) do
    Matrix4.Tensor.extract_rotations_batch(joint_tensor.global_transforms)
  end
end
