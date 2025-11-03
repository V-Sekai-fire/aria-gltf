# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaEwbik.Kusudama do
  @moduledoc """
  Kusudama constraint system for anatomical joint limitations.

  This module implements cone-based joint orientation constraints
  using AriaMath for quaternion operations and IEEE-754 compliance.
  """

  @doc """
  Create a Kusudama constraint for a joint.

  ## Parameters
  - `joint_id`: ID of the joint to constrain
  - `cone_specs`: List of cone specifications defining allowed orientations

  ## Returns
  - Constraint data structure
  """
  def create_constraint(joint_id, cone_specs) do
    %{
      joint_id: joint_id,
      cones: normalize_cone_specs(cone_specs),
      # Default twist limits in degrees
      twist_limits: {-180, 180},
      type: :kusudama
    }
  end

  @doc """
  Apply Kusudama constraints to a joint orientation.

  ## Parameters
  - `constraint`: Kusudama constraint data
  - `current_orientation`: Current joint orientation quaternion
  - `target_orientation`: Target joint orientation quaternion

  ## Returns
  - `{:ok, constrained_orientation}`: Valid constrained orientation
  - `{:error, reason}`: If constraint application fails
  """
  def apply_constraint(constraint, current_orientation, target_orientation) do
    try do
      # Check if target is within any cone
      case find_valid_cone(constraint.cones, target_orientation) do
        {:ok, _cone} ->
          # Target is valid, return it
          {:ok, target_orientation}

        :none ->
          # Target is outside all cones, find closest valid orientation
          find_closest_valid_orientation(constraint, current_orientation, target_orientation)
      end
    rescue
      error -> {:error, "Constraint application failed: #{inspect(error)}"}
    end
  end

  @doc """
  Validate that a pose satisfies all Kusudama constraints.

  ## Parameters
  - `constraints`: List of Kusudama constraints
  - `pose`: Joint pose data

  ## Returns
  - `:ok`: All constraints satisfied
  - `{:violations, violations}`: List of constraint violations
  """
  def validate_constraints(constraints, pose) do
    violations =
      Enum.filter(constraints, fn constraint ->
        joint_id = constraint.joint_id

        case Map.get(pose, joint_id) do
          # Joint not in pose, skip
          nil ->
            false

          orientation ->
            case apply_constraint(constraint, orientation, orientation) do
              # Constraint satisfied
              {:ok, ^orientation} -> false
              # Constraint violated
              _ -> true
            end
        end
      end)

    if Enum.empty?(violations) do
      :ok
    else
      {:violations, violations}
    end
  end

  # Private functions

  defp normalize_cone_specs(cone_specs) do
    # Normalize cone specifications to standard format
    Enum.map(cone_specs, fn cone ->
      case cone.type do
        :cone ->
          # Ensure center quaternion is normalized
          normalized_center = normalize_quaternion(cone.center)
          %{cone | center: normalized_center}

        :sequence ->
          # Recursively normalize nested cones
          normalized_cones = Enum.map(cone.cones, &(normalize_cone_specs([&1]) |> hd))
          %{cone | cones: normalized_cones}

        _ ->
          cone
      end
    end)
  end

  defp find_valid_cone(cones, orientation) do
    # Check if orientation falls within any cone
    Enum.find_value(cones, :none, fn cone ->
      case cone.type do
        :cone ->
          if orientation_within_cone?(orientation, cone) do
            {:ok, cone}
          else
            false
          end

        :sequence ->
          # For sequences, check if orientation is within any cone in the sequence
          Enum.find_value(cone.cones, false, fn sub_cone ->
            if orientation_within_cone?(orientation, sub_cone) do
              {:ok, sub_cone}
            else
              false
            end
          end)

        _ ->
          false
      end
    end)
  end

  defp find_closest_valid_orientation(constraint, current_orientation, target_orientation) do
    # Find the closest valid orientation within constraint bounds
    # For now, find the closest cone and project onto its surface
    case find_closest_cone(constraint.cones, target_orientation) do
      {:ok, closest_cone} ->
        # Project target orientation onto the cone surface
        projected = project_onto_cone(target_orientation, closest_cone)
        {:ok, projected}

      :none ->
        # No valid cones, return current orientation as fallback
        {:ok, current_orientation}
    end
  end

  # Quaternion mathematics helper functions

  defp orientation_within_cone?(orientation, cone) do
    # Calculate angle between orientation and cone center
    angle = quaternion_angle(orientation, cone.center)

    # Check if angle is within cone radius
    angle <= cone.radius
  end

  defp quaternion_angle(q1, q2) do
    # Calculate angle between two quaternions using dot product
    # cos(θ/2) = |q1 · q2|, so θ = 2 * acos(|q1 · q2|)
    dot_product = abs(quaternion_dot(q1, q2))

    # Clamp dot product to valid range for acos
    clamped_dot = max(-1.0, min(1.0, dot_product))

    # Return angle in radians
    2.0 * :math.acos(clamped_dot)
  end

  defp quaternion_dot({w1, x1, y1, z1}, {w2, x2, y2, z2}) do
    w1 * w2 + x1 * x2 + y1 * y2 + z1 * z2
  end

  defp normalize_quaternion({w, x, y, z}) do
    # Normalize quaternion to unit length
    magnitude = :math.sqrt(w * w + x * x + y * y + z * z)

    if magnitude > 0 do
      {w / magnitude, x / magnitude, y / magnitude, z / magnitude}
    else
      # Identity quaternion
      {1.0, 0.0, 0.0, 0.0}
    end
  end

  defp find_closest_cone(cones, target_orientation) do
    # Find the cone with the smallest angular distance to target
    {closest_cone, _min_angle} =
      Enum.reduce(cones, {nil, :math.pi()}, fn cone, {best_cone, min_angle} ->
        case cone.type do
          :cone ->
            angle = quaternion_angle(target_orientation, cone.center)

            if angle < min_angle do
              {cone, angle}
            else
              {best_cone, min_angle}
            end

          :sequence ->
            # For sequences, find closest sub-cone
            {seq_closest, seq_angle} =
              Enum.reduce(cone.cones, {nil, :math.pi()}, fn sub_cone, {best, min_ang} ->
                ang = quaternion_angle(target_orientation, sub_cone.center)

                if ang < min_ang do
                  {sub_cone, ang}
                else
                  {best, min_ang}
                end
              end)

            if seq_angle < min_angle do
              {seq_closest, seq_angle}
            else
              {best_cone, min_angle}
            end

          _ ->
            {best_cone, min_angle}
        end
      end)

    if closest_cone do
      {:ok, closest_cone}
    else
      :none
    end
  end

  defp project_onto_cone(_target_orientation, cone) do
    # Project target orientation onto the surface of the cone
    # This is a simplified projection - in practice, this would be more complex
    # For now, return the cone center as the closest valid orientation
    cone.center
  end

  @doc """
  Create a simple cone constraint.

  ## Parameters
  - `center`: Center orientation quaternion
  - `radius`: Cone radius in radians
  - `tangent_radius`: Tangent cone radius (optional)

  ## Returns
  - Cone specification map
  """
  def create_cone(center, radius, tangent_radius \\ nil) do
    %{
      center: center,
      radius: radius,
      tangent_radius: tangent_radius,
      type: :cone
    }
  end

  @doc """
  Create a sequence of cones for complex joint constraints.

  ## Parameters
  - `cones`: List of cone specifications

  ## Returns
  - Sequence constraint specification
  """
  def create_cone_sequence(cones) do
    %{
      cones: cones,
      type: :sequence
    }
  end

  @doc """
  Set twist limits for a constraint.

  ## Parameters
  - `constraint`: Existing constraint
  - `min_twist`: Minimum twist angle in degrees
  - `max_twist`: Maximum twist angle in degrees

  ## Returns
  - Updated constraint with twist limits
  """
  def set_twist_limits(constraint, min_twist, max_twist) do
    %{constraint | twist_limits: {min_twist, max_twist}}
  end

  @doc """
  Check if an orientation is within twist limits.

  ## Parameters
  - `constraint`: Constraint with twist limits
  - `orientation`: Orientation to check

  ## Returns
  - `:ok`: Within limits
  - `:twist_violation`: Outside twist limits
  """
  def check_twist_limits(_constraint, _orientation) do
    # TODO: Extract twist component from orientation
    # Compare against twist_limits
    :ok
  end
end
