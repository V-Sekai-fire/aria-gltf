# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaEwbik do
  @moduledoc """
  Entirely Wahba's-problem Based Inverse Kinematics (EWBIK) solver.

  AriaEwbik provides advanced multi-effector inverse kinematics solving with
  sophisticated constraint management, collision detection, and anti-uncanny
  valley features for realistic character animation.

  ## Features

  - **Multi-Effector IK Solving**: Coordinate multiple effectors simultaneously
  - **VRM1 Collision Detection**: Sphere, capsule, and plane collider support
  - **Anatomical Constraints**: Godot SkeletonProfileHumanoid integration
  - **Kusudama Constraints**: Cone-based joint orientation limits
  - **Anti-Uncanny Valley**: Sophisticated motion quality assurance
  - **AriaJoint Integration**: Leverages production-ready joint hierarchy system

  ## Usage

      # Basic IK solving
      {:ok, solved_skeleton} = AriaEwbik.solve_ik(skeleton, effector_targets)

      # Multi-effector coordination
      targets = [
        {left_hand_joint, target_position_1},
        {right_hand_joint, target_position_2}
      ]
      {:ok, solved_skeleton} = AriaEwbik.solve_multi_effector(skeleton, targets)

      # With VRM1 collision avoidance
      {:ok, solved_skeleton} = AriaEwbik.solve_with_collision_avoidance(
        skeleton,
        targets,
        vrm1_colliders
      )

  ## Architecture

  AriaEwbik uses a modular architecture built on mathematical foundations:

  - **AriaJoint**: Hierarchy management and transform operations
  - **AriaQCP**: Quaternion Characteristic Polynomial (Wahba's problem solver)
  - **AriaMath**: IEEE-754 compliant mathematical primitives
  - **AriaState**: Configuration storage for VRM1 and constraints

  ## Performance

  - **Multi-effector solving**: Optimized for real-time character animation
  - **Collision detection**: Efficient VRM1 collider validation
  - **Constraint evaluation**: Fast Kusudama cone validation
  - **Memory efficiency**: Registry-based joint state management
  """

  # Core EWBIK solving
  # TODO: Implement after internal modules are created
  # defdelegate solve_ik(skeleton, effector_targets, opts \\ []), to: AriaEwbik.Solver
  # defdelegate solve_multi_effector(skeleton, targets, opts \\ []), to: AriaEwbik.Solver

  # Skeleton analysis
  # TODO: Implement after segmentation module is created
  # defdelegate analyze_skeleton(joints), to: AriaEwbik.Segmentation
  # defdelegate segment_chains(skeleton, effectors), to: AriaEwbik.Segmentation

  # Constraint management
  # TODO: Implement after kusudama module is created
  # defdelegate create_kusudama_constraint(joint, cones), to: AriaEwbik.Kusudama
  # defdelegate validate_constraints(skeleton), to: AriaEwbik.Kusudama

  # VRM1 collision detection
  # TODO: Implement after VRM1 modules are created
  # defdelegate setup_vrm1_colliders(skeleton, collider_config), to: AriaEwbik.VRM1Colliders
  # defdelegate solve_with_collision_avoidance(skeleton, targets, colliders), to: AriaEwbik.VRM1CollisionSolver

  # Anatomical constraints
  # TODO: Implement after Godot integration modules are created
  # defdelegate apply_godot_anatomical_limits(skeleton), to: AriaEwbik.GodotSkeletonProfile
  # defdelegate convert_godot_to_gltf(godot_pose), to: AriaEwbik.CoordinateConversion

  @doc """
  Get AriaEwbik version information.

  ## Examples

      iex> AriaEwbik.version()
      "0.1.0"
  """
  def version do
    Application.spec(:aria_ewbik, :vsn) |> to_string()
  end

  @doc """
  Get AriaEwbik application information.

  ## Examples

      iex> info = AriaEwbik.info()
      iex> is_map(info)
      true
  """
  def info do
    %{
      name: "AriaEwbik",
      version: version(),
      description: "Entirely Wahba's-problem Based Inverse Kinematics solver",
      dependencies: [:aria_joint, :aria_qcp, :aria_math, :aria_state]
    }
  end
end
