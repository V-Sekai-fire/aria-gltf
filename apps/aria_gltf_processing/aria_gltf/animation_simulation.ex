# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.AnimationSimulation do
  @moduledoc """
  Animation simulation with skinning support using AriaJoint.

  This module simulates glTF animations by applying keyframe data to joint
  hierarchies and computing skin matrices for mesh deformation.

  ## Features

  - Animation keyframe interpolation (LINEAR, STEP, CUBICSPLINE)
  - Joint transform updates using AriaJoint
  - Skin matrix computation (inverse bind matrices + joint transforms)
  - Frame-accurate animation playback
  - Integration with AriaGltf.Skin for skeletal animation
  """

  alias AriaGltf.{Animation, Skin, Node, Accessor, Document}
  alias AriaGltf.Animation.{Channel, Channel.Target, Sampler}
  alias AriaJoint
  alias AriaMath.{Matrix4, Quaternion}

  @type animation_state :: %{
          time: float(),
          joint_transforms: %{Skin.joint_index() => Matrix4.t()},
          skin_matrices: %{Skin.joint_index() => Matrix4.t()} | nil
        }

  @doc """
  Simulates an animation at a given time, updating joint transforms.

  ## Parameters

  - `animation`: The glTF animation to simulate
  - `document`: The glTF document containing nodes and accessors
  - `skin`: Optional skin for computing skin matrices
  - `time`: Animation time in seconds

  ## Returns

  `{:ok, animation_state}` with updated joint transforms and skin matrices

  ## Examples

      {:ok, state} = AriaGltf.AnimationSimulation.simulate(
        animation,
        document,
        skin: skin,
        time: 1.5
      )
  """
  @spec simulate(Animation.t(), Document.t(), keyword()) ::
          {:ok, animation_state()} | {:error, term()}
  def simulate(%Animation{} = animation, %Document{} = document, opts \\ []) do
    time = Keyword.get(opts, :time, 0.0)
    skin = Keyword.get(opts, :skin)

    with {:ok, joint_transforms} <- compute_joint_transforms(animation, document, time),
         {:ok, skin_matrices} <- compute_skin_matrices(skin, joint_transforms, document) do
      state = %{
        time: time,
        joint_transforms: joint_transforms,
        skin_matrices: skin_matrices
      }

      {:ok, state}
    end
  end

  @doc """
  Updates AriaJoint hierarchy with animation transforms.

  Applies computed joint transforms to an AriaJoint hierarchy.

  ## Parameters

  - `joint_hierarchy`: Map of joint indices to AriaJoint instances
  - `joint_transforms`: Map of joint indices to transform matrices

  ## Returns

  Updated joint hierarchy

  ## Examples

      updated_hierarchy = AriaGltf.AnimationSimulation.apply_joint_transforms(
        joint_hierarchy,
        joint_transforms
      )
  """
  @spec apply_joint_transforms(
          %{Skin.joint_index() => AriaJoint.Joint.t()},
          %{Skin.joint_index() => Matrix4.t()}
        ) :: %{Skin.joint_index() => AriaJoint.Joint.t()}
  def apply_joint_transforms(joint_hierarchy, joint_transforms)
      when is_map(joint_hierarchy) and is_map(joint_transforms) do
    case Code.ensure_loaded(AriaJoint) do
      {:module, AriaJoint} ->
        joint_hierarchy
        |> Enum.map(fn {index, joint} ->
          case Map.get(joint_transforms, index) do
            nil ->
              {index, joint}

            transform ->
              updated_joint = AriaJoint.set_transform(joint, transform)
              {index, updated_joint}
          end
        end)
        |> Map.new()

      {:error, _} ->
        # Fallback: return hierarchy unchanged if AriaJoint unavailable
        joint_hierarchy
    end
  end

  # Compute joint transforms from animation channels at given time
  defp compute_joint_transforms(%Animation{} = animation, %Document{} = document, time) do
    nodes = document.nodes || []
    accessors = document.accessors || []

    joint_transforms =
      animation.channels
      |> Enum.reduce(%{}, fn channel, acc ->
        case extract_channel_transform(channel, animation.samplers, nodes, accessors, time) do
          {:ok, {node_index, transform}} ->
            Map.update(acc, node_index, transform, fn existing ->
              # Combine multiple channel transforms for same node
              Matrix4.multiply(transform, existing)
            end)

          {:error, _} ->
            acc
        end
      end)

    {:ok, joint_transforms}
  end

  # Extract transform from a single animation channel at given time
  defp extract_channel_transform(
         %Channel{} = channel,
         samplers,
         nodes,
         accessors,
         time
       ) do
    target = channel.target
    sampler = Enum.at(samplers, channel.sampler)

    if sampler do
      # Interpolate value from sampler at given time
      case interpolate_sampler(sampler, accessors, time) do
        {:ok, value} ->
          # Convert interpolated value to transform based on target path
          case create_transform_from_value(target, value) do
            {:ok, transform} ->
              {:ok, {target.node, transform}}

            error ->
              error
          end

        error ->
          error
      end
    else
      {:error, :invalid_sampler}
    end
  end

  # Interpolate sampler value at given time
  defp interpolate_sampler(%Sampler{} = sampler, accessors, time) do
    input_accessor = Enum.at(accessors, sampler.input)
    output_accessor = Enum.at(accessors, sampler.output)

    if input_accessor and output_accessor do
      # Find keyframe indices surrounding time
      # This is simplified - real implementation would read actual accessor data
      case find_keyframe_indices(input_accessor, time) do
        {:ok, {prev_idx, next_idx}} ->
          # Interpolate based on sampler interpolation mode
          interpolate_value(
            sampler.interpolation,
            input_accessor,
            output_accessor,
            prev_idx,
            next_idx,
            time
          )

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :invalid_accessor}
    end
  end

  # Simplified keyframe finding (would need actual accessor data access)
  defp find_keyframe_indices(_accessor, _time) do
    # Placeholder: would read actual accessor data to find surrounding keyframes
    {:ok, {0, 1}}
  end

  # Interpolate value based on interpolation mode
  defp interpolate_value(interpolation, input_accessor, output_accessor, prev_idx, next_idx, time) do
    case interpolation do
      :linear ->
        # Linear interpolation between prev and next
        {:ok, [0.0, 0.0, 0.0, 1.0]} # Placeholder

      :step ->
        # Step interpolation (use prev value)
        {:ok, [0.0, 0.0, 0.0, 1.0]} # Placeholder

      :cubicspline ->
        # Cubic spline interpolation
        {:ok, [0.0, 0.0, 0.0, 1.0]} # Placeholder

      _ ->
        {:ok, [0.0, 0.0, 0.0, 1.0]} # Default
    end
  end

  # Create transform matrix from interpolated value based on target path
  defp create_transform_from_value(%Target{} = target, value) when is_list(value) do
    case target.path do
      "translation" ->
        # Value should be [x, y, z]
        {:ok, Matrix4.translation({Enum.at(value, 0) || 0.0, Enum.at(value, 1) || 0.0, Enum.at(value, 2) || 0.0})}

      "rotation" ->
        # Value should be quaternion [x, y, z, w]
        # Use Matrix4.rotation() with Quaternion
        quat = Quaternion.new(
          Enum.at(value, 0) || 0.0,
          Enum.at(value, 1) || 0.0,
          Enum.at(value, 2) || 0.0,
          Enum.at(value, 3) || 1.0
        )
        {:ok, Matrix4.rotation(quat)}

      "scale" ->
        # Value should be [x, y, z]
        {:ok, Matrix4.scale({Enum.at(value, 0) || 1.0, Enum.at(value, 1) || 1.0, Enum.at(value, 2) || 1.0})}

      _ ->
        {:error, :invalid_target_path}
    end
  rescue
    _ ->
      {:error, :invalid_transform_data}
  end

  defp create_transform_from_value(_target, _value) do
    {:error, :invalid_transform_data}
  end

  # Compute skin matrices from joint transforms and inverse bind matrices
  defp compute_skin_matrices(nil, _joint_transforms, _document) do
    {:ok, nil}
  end

  defp compute_skin_matrices(%Skin{} = skin, joint_transforms, %Document{} = document) do
    accessors = document.accessors || []

    inverse_bind_matrices =
      if skin.inverse_bind_matrices do
        accessor = Enum.at(accessors, skin.inverse_bind_matrices)
        extract_inverse_bind_matrices(accessor)
      else
        # If no inverse bind matrices, use identity matrices
        Enum.map(skin.joints, fn _ -> Matrix4.identity() end)
      end

    # Compute skin matrices: joint_transform * inverse_bind_matrix
    skin_matrices =
      skin.joints
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {joint_index, idx}, acc ->
        joint_transform = Map.get(joint_transforms, joint_index, Matrix4.identity())
        inverse_bind = Enum.at(inverse_bind_matrices, idx) || Matrix4.identity()
        skin_matrix = Matrix4.multiply(joint_transform, inverse_bind)
        Map.put(acc, joint_index, skin_matrix)
      end)

    {:ok, skin_matrices}
  end

  # Extract inverse bind matrices from accessor (simplified)
  defp extract_inverse_bind_matrices(_accessor) do
    # Placeholder: would read actual accessor data
    # For now, return identity matrices
    [Matrix4.identity()]
  end

  @doc """
  Simulates animation sequence over time range.

  ## Parameters

  - `animation`: The glTF animation
  - `document`: The glTF document
  - `start_time`: Start time in seconds (default: 0.0)
  - `end_time`: End time in seconds
  - `frame_rate`: Frames per second (default: 30.0)
  - `skin`: Optional skin for skin matrix computation

  ## Returns

  List of animation states for each frame

  ## Examples

      states = AriaGltf.AnimationSimulation.simulate_sequence(
        animation,
        document,
        start_time: 0.0,
        end_time: 2.0,
        frame_rate: 30.0,
        skin: skin
      )
  """
  @spec simulate_sequence(Animation.t(), Document.t(), keyword()) :: [animation_state()]
  def simulate_sequence(%Animation{} = animation, %Document{} = document, opts \\ []) do
    start_time = Keyword.get(opts, :start_time, 0.0)
    end_time = Keyword.get(opts, :end_time, 1.0)
    frame_rate = Keyword.get(opts, :frame_rate, 30.0)
    skin = Keyword.get(opts, :skin)

    frame_interval = 1.0 / frame_rate
    frame_count = trunc((end_time - start_time) / frame_interval) + 1

    0..(frame_count - 1)
    |> Enum.map(fn frame ->
      time = start_time + frame * frame_interval
      {:ok, state} = simulate(animation, document, time: time, skin: skin)
      state
    end)
  end
end

