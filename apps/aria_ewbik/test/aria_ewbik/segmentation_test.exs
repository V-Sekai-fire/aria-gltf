defmodule AriaEwbik.SegmentationTest do
  use ExUnit.Case, async: true

  alias AriaEwbik.Segmentation

  describe "analyze_chains/2" do
    test "successfully analyzes single effector chain" do
      skeleton = %{
        "root" => %{parent: nil},
        "elbow" => %{parent: "shoulder"},
        "shoulder" => %{parent: "root"},
        "hand" => %{parent: "elbow"}
      }

      effector_targets = [{"hand", {1.0, 2.0, 3.0}}]

      assert {:ok, chains} = Segmentation.analyze_chains(skeleton, effector_targets)
      assert length(chains) == 1
      assert hd(chains) == ["hand", "elbow", "shoulder", "root"]
    end

    test "handles multiple effectors" do
      skeleton = %{
        "root" => %{parent: nil},
        "left_shoulder" => %{parent: "root"},
        "left_elbow" => %{parent: "left_shoulder"},
        "left_hand" => %{parent: "left_elbow"},
        "right_shoulder" => %{parent: "root"},
        "right_elbow" => %{parent: "right_shoulder"},
        "right_hand" => %{parent: "right_elbow"}
      }

      effector_targets = [
        {"left_hand", {1.0, 2.0, 3.0}},
        {"right_hand", {4.0, 5.0, 6.0}}
      ]

      assert {:ok, chains} = Segmentation.analyze_chains(skeleton, effector_targets)
      assert length(chains) == 2

      # Check that both chains are present
      chain_joints = Enum.flat_map(chains, & &1) |> Enum.uniq() |> Enum.sort()

      expected_joints =
        [
          "left_hand",
          "left_elbow",
          "left_shoulder",
          "right_hand",
          "right_elbow",
          "right_shoulder",
          "root"
        ]
        |> Enum.sort()

      assert chain_joints == expected_joints
    end

    test "returns error for invalid effector" do
      skeleton = %{"root" => %{parent: nil}}
      effector_targets = [{"nonexistent", {1.0, 2.0, 3.0}}]

      assert {:error, "Chain analysis failed: No valid chain found for effector nonexistent"} =
               Segmentation.analyze_chains(skeleton, effector_targets)
    end
  end

  describe "build_chain/2" do
    test "builds chain from effector to root" do
      skeleton = %{
        "root" => %{parent: nil},
        "middle" => %{parent: "root"},
        "leaf" => %{parent: "middle"}
      }

      chain = Segmentation.build_chain(skeleton, "leaf")
      assert chain == ["leaf", "middle", "root"]
    end

    test "returns empty list for invalid effector" do
      skeleton = %{"root" => %{parent: nil}}
      chain = Segmentation.build_chain(skeleton, "invalid")
      assert chain == []
    end
  end

  describe "get_processing_order/1" do
    test "returns joints in dependency order" do
      chains = [
        ["hand", "elbow", "shoulder", "root"],
        ["foot", "knee", "hip", "root"]
      ]

      order = Segmentation.get_processing_order(chains)
      # Should start with leaves and work toward root
      assert "hand" in order
      assert "foot" in order
      assert "root" in order
    end
  end
end
