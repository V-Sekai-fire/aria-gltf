defmodule AriaEwbik.PropagationTest do
  use ExUnit.Case, async: true

  alias AriaEwbik.Propagation

  describe "calculate_propagation_factors/2" do
    test "calculates factors for simple chain" do
      chain = ["hand", "wrist", "elbow", "shoulder"]
      effector_influence = 1.0

      factors = Propagation.calculate_propagation_factors(chain, effector_influence)

      # Hand (closest to effector) should have highest influence
      assert factors["hand"] > factors["wrist"]
      assert factors["wrist"] > factors["elbow"]
      assert factors["elbow"] > factors["shoulder"]

      # All factors should be positive
      assert Enum.all?(Map.values(factors), &(&1 > 0))
    end

    test "respects effector influence" do
      chain = ["hand", "wrist", "elbow"]
      high_influence = 2.0
      low_influence = 0.5

      high_factors = Propagation.calculate_propagation_factors(chain, high_influence)
      low_factors = Propagation.calculate_propagation_factors(chain, low_influence)

      # High influence should result in higher factors
      assert high_factors["hand"] > low_factors["hand"]
      assert high_factors["wrist"] > low_factors["wrist"]
    end
  end

  describe "combine_multi_effector_solutions/2" do
    test "combines solutions from multiple effectors" do
      solutions = [
        # ~5 degrees
        {"left_hand", [{"elbow", {0, 0.1, 0, 0.995}}]},
        # ~10 degrees
        {"right_hand", [{"elbow", {0, 0.2, 0, 0.98}}]}
      ]

      hierarchy = %{"elbow" => %{parent: "shoulder"}}

      result = Propagation.combine_multi_effector_solutions(solutions, hierarchy)
      assert is_map(result)
      assert Map.has_key?(result, "elbow")
    end

    test "handles single effector" do
      solutions = [
        {"hand", [{"wrist", {0, 0.1, 0, 0.995}}]}
      ]

      hierarchy = %{"wrist" => %{parent: "elbow"}}

      result = Propagation.combine_multi_effector_solutions(solutions, hierarchy)
      assert is_map(result)
      assert Map.has_key?(result, "wrist")
    end
  end

  describe "effector_type_weight/2" do
    test "gives higher weight to ultimate effectors" do
      ultimate_weight = Propagation.effector_type_weight(:ultimate, 1.0)
      intermediary_weight = Propagation.effector_type_weight(:intermediary, 1.0)

      assert ultimate_weight > intermediary_weight
      assert ultimate_weight == 1.2
      assert intermediary_weight == 0.8
    end

    test "returns base weight for unknown types" do
      weight = Propagation.effector_type_weight(:unknown, 1.5)
      assert weight == 1.5
    end
  end

  describe "create_propagation_config/3" do
    test "creates propagation configuration" do
      config = Propagation.create_propagation_config("hand", 1.5, 0.7)

      assert config.effector_id == "hand"
      assert config.base_influence == 1.5
      assert config.decay_rate == 0.7
      assert config.type == :propagation
    end

    test "uses default decay rate" do
      config = Propagation.create_propagation_config("foot", 2.0)

      assert config.decay_rate == 0.8
    end
  end

  describe "smooth_propagation/3" do
    test "smooths propagation factors" do
      current = %{"joint1" => 1.0, "joint2" => 0.8}
      previous = %{"joint1" => 0.5, "joint2" => 0.9}
      smoothing_factor = 0.5

      smoothed = Propagation.smooth_propagation(current, previous, smoothing_factor)

      # Should interpolate between current and previous
      assert smoothed["joint1"] > previous["joint1"]
      assert smoothed["joint1"] < current["joint1"]
      assert smoothed["joint2"] > current["joint2"]
      assert smoothed["joint2"] < previous["joint2"]
    end

    test "handles missing previous values" do
      current = %{"joint1" => 1.0, "joint2" => 0.8}
      # Missing joint2
      previous = %{"joint1" => 0.5}
      smoothing_factor = 0.3

      smoothed = Propagation.smooth_propagation(current, previous, smoothing_factor)

      # joint1 should be smoothed
      assert smoothed["joint1"] > previous["joint1"]
      assert smoothed["joint1"] < current["joint1"]

      # joint2 should use current value (no previous to smooth with)
      assert smoothed["joint2"] == current["joint2"]
    end
  end

  describe "propagation behavior" do
    test "maintains joint ordering in processing" do
      chain = ["finger", "hand", "wrist", "elbow", "shoulder"]
      factors = Propagation.calculate_propagation_factors(chain, 1.0)

      # Verify all joints from chain are in factors
      Enum.each(chain, fn joint ->
        assert Map.has_key?(factors, joint)
        assert factors[joint] > 0
      end)
    end

    test "handles empty chain" do
      factors = Propagation.calculate_propagation_factors([], 1.0)
      assert factors == %{}
    end

    test "handles single joint chain" do
      factors = Propagation.calculate_propagation_factors(["hand"], 1.0)
      assert factors["hand"] == 1.0
    end
  end
end
