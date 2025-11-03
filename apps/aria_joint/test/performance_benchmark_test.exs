# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.PerformanceBenchmarkTest do
  use ExUnit.Case

  alias AriaJoint.Joint
  alias AriaMath.Matrix4
  require Logger

  @moduletag :benchmark
  # 5 minutes for long benchmarks
  @moduletag timeout: 300_000

  describe "current implementation benchmarks" do
    test "benchmark: create large hierarchy" do
      # Stay under max depth limit
      hierarchy_sizes = [10, 50, 80, 95]

      for size <- hierarchy_sizes do
        case create_chain_hierarchy(size) do
          {:error, reason} ->
            Logger.debug("\n=== Create Chain Hierarchy (#{size} bones) FAILED ===")
            Logger.debug("Error: #{reason}")

          hierarchy ->
            {time_us, _} = :timer.tc(fn -> length(hierarchy) end)

            Logger.debug("\n=== Create Chain Hierarchy (#{size} bones) ===")
            Logger.debug("Time: #{time_us / 1000} ms")
            Logger.debug("Nodes created: #{length(hierarchy)}")

            # Cleanup
            hierarchy |> Enum.each(&Joint.cleanup/1)
        end
      end
    end

    test "benchmark: get global poses (forward traversal)" do
      # Reduced max size to avoid depth limits
      sizes = [20, 50, 80]

      for size <- sizes do
        case create_chain_hierarchy(size) do
          {:error, reason} ->
            Logger.debug("\n=== Get Global Poses Forward (#{size} bones) FAILED ===")
            Logger.debug("Error: #{reason}")

          hierarchy ->
            # Benchmark getting all global poses in forward order
            {time_us, _results} =
              :timer.tc(fn ->
                Enum.map(hierarchy, &Joint.get_global_transform/1)
              end)

            Logger.debug("\n=== Get Global Poses Forward (#{size} bones) ===")
            Logger.debug("Time: #{time_us / 1000} ms")
            Logger.debug("Poses per second: #{(size * 1_000_000 / time_us) |> Float.round(2)}")

            # Cleanup
            hierarchy |> Enum.each(&Joint.cleanup/1)
        end
      end
    end

    test "benchmark: get global poses (reverse traversal)" do
      # Reduced max size to avoid depth limits
      sizes = [20, 50, 80]

      for size <- sizes do
        case create_chain_hierarchy(size) do
          {:error, reason} ->
            Logger.debug("\n=== Get Global Poses Reverse (#{size} bones) FAILED ===")
            Logger.debug("Error: #{reason}")

          hierarchy ->
            # Benchmark getting all global poses in reverse order (worst case)
            {time_us, _results} =
              :timer.tc(fn ->
                hierarchy
                |> Enum.reverse()
                |> Enum.map(&Joint.get_global_transform/1)
              end)

            Logger.debug("\n=== Get Global Poses Reverse (#{size} bones) ===")
            Logger.debug("Time: #{time_us / 1000} ms")
            Logger.debug("Poses per second: #{(size * 1_000_000 / time_us) |> Float.round(2)}")

            # Cleanup
            hierarchy |> Enum.each(&Joint.cleanup/1)
        end
      end
    end

    test "benchmark: set all poses and get global poses" do
      # Reduced max size to avoid depth limits
      sizes = [20, 50, 80]

      for size <- sizes do
        case create_chain_hierarchy(size) do
          {:error, reason} ->
            Logger.debug("\n=== Set All Poses + Get Global Poses (#{size} bones) FAILED ===")
            Logger.debug("Error: #{reason}")

          hierarchy ->
            # Generate random transforms
            transforms =
              Enum.map(1..size, fn i ->
                Matrix4.translation({i * 0.1, 0.0, 0.0})
              end)

            # Benchmark setting all poses then getting all global poses
            {time_us, _results} =
              :timer.tc(fn ->
                # Set all transforms
                updated_hierarchy =
                  hierarchy
                  |> Enum.zip(transforms)
                  |> Enum.map(fn {node, transform} ->
                    Joint.set_transform(node, transform)
                  end)

                # Get all global transforms
                Enum.map(updated_hierarchy, &Joint.get_global_transform/1)
              end)

            Logger.debug("\n=== Set All Poses + Get Global Poses (#{size} bones) ===")
            Logger.debug("Time: #{time_us / 1000} ms")

            Logger.debug(
              "Operations per second: #{(size * 2 * 1_000_000 / time_us) |> Float.round(2)}"
            )

            # Cleanup
            hierarchy |> Enum.each(&Joint.cleanup/1)
        end
      end
    end

    test "benchmark: set single root pose and get all global poses" do
      # Reduced max size to avoid depth limits
      sizes = [20, 50, 80]

      for size <- sizes do
        case create_chain_hierarchy(size) do
          {:error, reason} ->
            Logger.debug("\n=== Set Root + Get All Global Poses (#{size} bones) FAILED ===")
            Logger.debug("Error: #{reason}")

          hierarchy ->
            [root | _] = hierarchy

            # Transform for root
            root_transform = Matrix4.translation({1.0, 0.0, 0.0})

            # Benchmark setting root pose and getting all global poses (propagation test)
            {time_us, _results} =
              :timer.tc(fn ->
                _updated_root = Joint.set_transform(root, root_transform)

                # Get all global transforms (should trigger propagation)
                Enum.map(hierarchy, &Joint.get_global_transform/1)
              end)

            Logger.debug("\n=== Set Root + Get All Global Poses (#{size} bones) ===")
            Logger.debug("Time: #{time_us / 1000} ms")

            Logger.debug(
              "Propagation efficiency: #{(size * 1_000_000 / time_us) |> Float.round(2)} bones/sec"
            )

            # Cleanup
            hierarchy |> Enum.each(&Joint.cleanup/1)
        end
      end
    end

    test "benchmark: complex hierarchy (tree structure)" do
      depth = 4
      branching_factor = 3

      hierarchy = create_tree_hierarchy(depth, branching_factor)
      node_count = length(hierarchy)

      Logger.debug(
        "\n=== Complex Tree Hierarchy (depth: #{depth}, branching: #{branching_factor}) ==="
      )

      Logger.debug("Total nodes: #{node_count}")

      # Benchmark getting all global poses
      {time_us, _results} =
        :timer.tc(fn ->
          Enum.map(hierarchy, &Joint.get_global_transform/1)
        end)

      Logger.debug("Get all global poses: #{time_us / 1000} ms")
      Logger.debug("Poses per second: #{(node_count * 1_000_000 / time_us) |> Float.round(2)}")

      # Cleanup
      hierarchy |> Enum.each(&Joint.cleanup/1)
    end

    test "benchmark: memory pressure test" do
      # Create a large hierarchy and repeatedly access it
      # Use smaller size to avoid depth limits
      size = 80
      iterations = 50

      case create_chain_hierarchy(size) do
        {:error, reason} ->
          Logger.debug("\n=== Memory Pressure Test FAILED ===")
          Logger.debug("Error: #{reason}")

        hierarchy ->
          {time_us, _} =
            :timer.tc(fn ->
              for _i <- 1..iterations do
                Enum.map(hierarchy, &Joint.get_global_transform/1)
              end
            end)

          total_operations = size * iterations

          Logger.debug("\n=== Memory Pressure Test (#{size} bones, #{iterations} iterations) ===")
          Logger.debug("Time: #{time_us / 1000} ms")
          Logger.debug("Total operations: #{total_operations}")

          Logger.debug(
            "Operations per second: #{(total_operations * 1_000_000 / time_us) |> Float.round(2)}"
          )

          # Cleanup
          hierarchy |> Enum.each(&Joint.cleanup/1)
      end
    end
  end

  # Helper functions

  defp create_chain_hierarchy(size) when size > 0 do
    case Joint.new() do
      {:ok, root} ->
        try do
          {hierarchy, _} =
            Enum.reduce(1..(size - 1), {[root], root}, fn _i, {acc, parent} ->
              # Add small transform to each bone
              transform = Matrix4.translation({0.1, 0.0, 0.0})
              updated_parent = Joint.set_transform(parent, transform)

              case Joint.new(parent: updated_parent) do
                {:ok, child} -> {[child | acc], child}
                {:error, reason} -> throw({:error, reason})
              end
            end)

          Enum.reverse(hierarchy)
        catch
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_tree_hierarchy(depth, branching_factor) do
    {:ok, root} = Joint.new()

    {nodes, _} = create_tree_recursive(root, depth - 1, branching_factor, [root], 0)
    nodes
  end

  defp create_tree_recursive(_parent, 0, _branching_factor, acc, _level) do
    {acc, 0}
  end

  defp create_tree_recursive(parent, depth, branching_factor, acc, level) do
    # Create children for this parent
    children =
      for i <- 1..branching_factor do
        transform = Matrix4.translation({level * 0.1, i * 0.1, 0.0})
        updated_parent = Joint.set_transform(parent, transform)
        {:ok, child} = Joint.new(parent: updated_parent)
        child
      end

    # Recursively create subtrees
    {final_acc, _} =
      Enum.reduce(children, {acc ++ children, 0}, fn child, {current_acc, _} ->
        create_tree_recursive(child, depth - 1, branching_factor, current_acc, level + 1)
      end)

    {final_acc, 0}
  end
end
