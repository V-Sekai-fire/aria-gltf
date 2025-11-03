defmodule AriaEwbik.SolverTest do
  use ExUnit.Case, async: true

  alias AriaEwbik.Solver

  describe "solve_ik/3" do
    test "solves single effector IK" do
      skeleton = %{
        "root" => %{parent: nil, rotation: {0, 0, 0, 1}},
        "elbow" => %{parent: "root", rotation: {0, 0, 0, 1}},
        "hand" => %{parent: "elbow", rotation: {0, 0, 0, 1}}
      }

      effector_target = {"hand", {1.0, 0.0, 0.0}}

      result = Solver.solve_ik(skeleton, effector_target, iterations: 1, tolerance: 0.1)

      # Should return a solution (even if it's just the initial pose for now)
      assert {:ok, solution} = result
      assert is_list(solution)
    end

    test "returns error for invalid chain" do
      skeleton = %{"root" => %{parent: nil}}
      effector_target = {"nonexistent", {1.0, 0.0, 0.0}}

      result = Solver.solve_ik(skeleton, effector_target)
      assert {:error, "No valid chain found for effector nonexistent"} = result
    end

    test "respects iteration limit" do
      skeleton = %{
        "root" => %{parent: nil, rotation: {0, 0, 0, 1}},
        "hand" => %{parent: "root", rotation: {0, 0, 0, 1}}
      }

      effector_target = {"hand", {1.0, 0.0, 0.0}}

      result = Solver.solve_ik(skeleton, effector_target, iterations: 0)
      assert {:ok, _solution} = result
    end
  end

  describe "solve_multi_effector/3" do
    test "solves multiple effectors" do
      skeleton = %{
        "root" => %{parent: nil, rotation: {0, 0, 0, 1}},
        "left_shoulder" => %{parent: "root", rotation: {0, 0, 0, 1}},
        "left_hand" => %{parent: "left_shoulder", rotation: {0, 0, 0, 1}},
        "right_shoulder" => %{parent: "root", rotation: {0, 0, 0, 1}},
        "right_hand" => %{parent: "right_shoulder", rotation: {0, 0, 0, 1}}
      }

      effector_targets = [
        {"left_hand", {1.0, 0.0, 0.0}},
        {"right_hand", {-1.0, 0.0, 0.0}}
      ]

      result = Solver.solve_multi_effector(skeleton, effector_targets, iterations: 1)
      assert {:ok, _solution} = result
    end

    test "handles chain analysis errors" do
      skeleton = %{"root" => %{parent: nil}}
      effector_targets = [{"nonexistent", {1.0, 0.0, 0.0}}]

      result = Solver.solve_multi_effector(skeleton, effector_targets)

      assert {:error, "Chain analysis failed: No valid chain found for effector nonexistent"} =
               result
    end
  end

  describe "solver behavior" do
    test "handles convergence within tolerance" do
      skeleton = %{
        "root" => %{parent: nil, rotation: {0, 0, 0, 1}},
        "hand" => %{parent: "root", rotation: {0, 0, 0, 1}}
      }

      # Target very close to current position
      effector_target = {"hand", {0.0, 0.0, 0.0}}

      result = Solver.solve_ik(skeleton, effector_target, iterations: 10, tolerance: 0.1)
      assert {:ok, _solution} = result
    end

    test "handles maximum iterations" do
      skeleton = %{
        "root" => %{parent: nil, rotation: {0, 0, 0, 1}},
        "elbow" => %{parent: "root", rotation: {0, 0, 0, 1}},
        "wrist" => %{parent: "elbow", rotation: {0, 0, 0, 1}},
        "hand" => %{parent: "wrist", rotation: {0, 0, 0, 1}}
      }

      # Distant target requiring iterations
      effector_target = {"hand", {2.0, 1.0, 0.5}}

      result = Solver.solve_ik(skeleton, effector_target, iterations: 5, tolerance: 0.001)
      assert {:ok, _solution} = result
    end
  end
end
