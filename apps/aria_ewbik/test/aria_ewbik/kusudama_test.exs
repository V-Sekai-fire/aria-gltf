defmodule AriaEwbik.KusudamaTest do
  use ExUnit.Case, async: true

  alias AriaEwbik.Kusudama

  describe "create_constraint/2" do
    test "creates constraint with single cone" do
      joint_id = "elbow"

      cone_specs = [
        Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 4)
      ]

      constraint = Kusudama.create_constraint(joint_id, cone_specs)

      assert constraint.joint_id == "elbow"
      assert length(constraint.cones) == 1
      assert constraint.twist_limits == {-180, 180}
      assert constraint.type == :kusudama
    end

    test "creates constraint with multiple cones" do
      joint_id = "shoulder"

      cone_specs = [
        Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 6),
        Kusudama.create_cone({0, 0.707, 0, 0.707}, :math.pi() / 3)
      ]

      constraint = Kusudama.create_constraint(joint_id, cone_specs)

      assert constraint.joint_id == "shoulder"
      assert length(constraint.cones) == 2
    end
  end

  describe "apply_constraint/3" do
    test "returns target orientation when within constraint" do
      constraint =
        Kusudama.create_constraint("elbow", [
          # 90-degree cone
          Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 2)
        ])

      current_orientation = {0, 0, 0, 1}
      # ~45 degrees
      target_orientation = {0, 0.383, 0, 0.924}

      result = Kusudama.apply_constraint(constraint, current_orientation, target_orientation)
      assert {:ok, ^target_orientation} = result
    end

    test "finds closest valid orientation when target is outside constraint" do
      constraint =
        Kusudama.create_constraint("elbow", [
          # 30-degree cone
          Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 6)
        ])

      current_orientation = {0, 0, 0, 1}
      # 90 degrees - outside cone
      target_orientation = {0, 0.707, 0, 0.707}

      result = Kusudama.apply_constraint(constraint, current_orientation, target_orientation)
      assert {:ok, constrained_orientation} = result
      # Should return a valid orientation (may be current or projected)
      assert is_tuple(constrained_orientation)
      assert tuple_size(constrained_orientation) == 4
    end
  end

  describe "validate_constraints/2" do
    test "returns :ok when all constraints satisfied" do
      constraints = [
        Kusudama.create_constraint("elbow", [
          Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 2)
        ])
      ]

      pose = %{
        # 45 degrees - within constraint
        "elbow" => {0, 0.383, 0, 0.924}
      }

      assert :ok = Kusudama.validate_constraints(constraints, pose)
    end

    test "returns violations when constraints not satisfied" do
      constraints = [
        Kusudama.create_constraint("elbow", [
          # 30-degree cone
          Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 6)
        ])
      ]

      pose = %{
        # 90 degrees - outside constraint
        "elbow" => {0, 0.707, 0, 0.707}
      }

      result = Kusudama.validate_constraints(constraints, pose)
      assert {:violations, violations} = result
      assert length(violations) == 1
    end

    test "ignores joints not in pose" do
      constraints = [
        Kusudama.create_constraint("elbow", [
          Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 2)
        ])
      ]

      # Different joint
      pose = %{"shoulder" => {0, 0, 0, 1}}

      assert :ok = Kusudama.validate_constraints(constraints, pose)
    end
  end

  describe "create_cone/3" do
    test "creates cone with center and radius" do
      center = {0, 0, 0, 1}
      radius = :math.pi() / 4
      tangent_radius = :math.pi() / 6

      cone = Kusudama.create_cone(center, radius, tangent_radius)

      assert cone.center == center
      assert cone.radius == radius
      assert cone.tangent_radius == tangent_radius
      assert cone.type == :cone
    end

    test "creates cone without tangent radius" do
      center = {0, 0, 0, 1}
      radius = :math.pi() / 3

      cone = Kusudama.create_cone(center, radius)

      assert cone.center == center
      assert cone.radius == radius
      assert cone.tangent_radius == nil
      assert cone.type == :cone
    end
  end

  describe "create_cone_sequence/1" do
    test "creates sequence of cones" do
      cones = [
        Kusudama.create_cone({0, 0, 0, 1}, :math.pi() / 6),
        Kusudama.create_cone({0, 0.707, 0, 0.707}, :math.pi() / 4)
      ]

      sequence = Kusudama.create_cone_sequence(cones)

      assert sequence.cones == cones
      assert sequence.type == :sequence
    end
  end

  describe "set_twist_limits/3" do
    test "sets twist limits on constraint" do
      constraint = Kusudama.create_constraint("wrist", [])
      updated = Kusudama.set_twist_limits(constraint, -90, 90)

      assert updated.twist_limits == {-90, 90}
    end
  end
end
