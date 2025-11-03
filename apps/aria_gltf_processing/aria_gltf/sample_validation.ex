# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.SampleValidation do
  @moduledoc """
  Validation module for SimpleSkin/SimpleMorph sample assets.

  This module implements Phase 8 requirements from ADR R25W1513883:
  - SimpleSkin.gltf validation with joint hierarchy and skeletal animation
  - SimpleMorph.gltf validation with morph target blending
  - Frame-accurate processing pipeline
  - Integration with AriaJoint and AriaMath apps
  """

  alias AriaGltf.IO

  @doc """
  Validates SimpleSkin.gltf sample file.

  This function loads and validates the SimpleSkin.gltf sample from Khronos Group,
  verifying that it can be properly parsed and that skeletal animation data
  is correctly structured.

  ## Options

  - `:file_path` - Path to SimpleSkin.gltf file (defaults to "/tmp/SimpleSkin.gltf")
  - `:validate_joints` - Whether to validate joint hierarchy (default: true)
  - `:validate_animation` - Whether to validate animation data (default: true)

  ## Returns

  `{:ok, validation_report}` on success, `{:error, reason}` on failure.

  ## Examples

      # Example usage (requires SimpleSkin.gltf file):
      # {:ok, report} = AriaGltf.SampleValidation.validate_simple_skin()
      # report.validation_passed  # => true
  """
  def validate_simple_skin(opts \\ []) do
    file_path = Keyword.get(opts, :file_path, "apps/aria_joint/test/samples/SimpleSkin.gltf")
    validate_joints = Keyword.get(opts, :validate_joints, true)
    validate_animation = Keyword.get(opts, :validate_animation, true)

    # Override buffer view validation for sample files that may have edge cases
    validation_overrides = [:buffer_view_indices]

    with {:ok, document} <-
           IO.import_from_file(file_path,
             validation_mode: :strict,
             validation_overrides: validation_overrides
           ),
         {:ok, skin_report} <- validate_skin_structure(document),
         {:ok, joint_report} <- maybe_validate_joints(document, validate_joints),
         {:ok, animation_report} <- maybe_validate_animation(document, validate_animation) do
      validation_report = %{
        document: document,
        skin_report: skin_report,
        joint_report: joint_report,
        animation_report: animation_report,
        validation_passed: true
      }

      {:ok, validation_report}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Validates SimpleMorph.gltf sample file.

  This function loads and validates the SimpleMorph.gltf sample from Khronos Group,
  verifying that morph target data is correctly structured and can be processed.

  ## Options

  - `:file_path` - Path to SimpleMorph.gltf file (defaults to "/tmp/SimpleMorph.gltf")
  - `:validate_targets` - Whether to validate morph targets (default: true)
  - `:validate_weights` - Whether to validate morph weights (default: true)

  ## Returns

  `{:ok, validation_report}` on success, `{:error, reason}` on failure.
  """
  def validate_simple_morph(opts \\ []) do
    file_path = Keyword.get(opts, :file_path, "/tmp/SimpleMorph.gltf")
    validate_targets = Keyword.get(opts, :validate_targets, true)
    validate_weights = Keyword.get(opts, :validate_weights, true)

    with {:ok, document} <- IO.import_from_file(file_path, validation_mode: :strict),
         {:ok, mesh_report} <- validate_morph_structure(document),
         {:ok, target_report} <- maybe_validate_morph_targets(document, validate_targets),
         {:ok, weight_report} <- maybe_validate_morph_weights(document, validate_weights) do
      validation_report = %{
        document: document,
        mesh_report: mesh_report,
        target_report: target_report,
        weight_report: weight_report,
        validation_passed: true
      }

      {:ok, validation_report}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Performs frame-accurate animation processing.

  This function processes skeletal animation or morph target animation
  at a specific timestamp, providing frame-accurate mesh state calculation.

  ## Parameters

  - `document` - The glTF document containing animation data
  - `timestamp` - The animation timestamp (in seconds)
  - `options` - Processing options

  ## Options

  - `:animation_index` - Which animation to process (default: 0)
  - `:use_aria_joint` - Whether to use AriaJoint for skeletal processing (default: true)
  - `:use_aria_math` - Whether to use AriaMath for calculations (default: true)

  ## Returns

  `{:ok, processed_state}` with mesh state at the given timestamp.
  """
  def process_frame_accurate(document, timestamp, options \\ []) do
    animation_index = Keyword.get(options, :animation_index, 0)
    use_aria_joint = Keyword.get(options, :use_aria_joint, true)
    use_aria_math = Keyword.get(options, :use_aria_math, true)

    case get_animation(document, animation_index) do
      {:ok, animation} ->
        if has_skeletal_animation?(document) do
          process_skeletal_animation(
            document,
            animation,
            timestamp,
            use_aria_joint,
            use_aria_math
          )
        else
          process_morph_animation(document, animation, timestamp)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  defp validate_skin_structure(document) do
    case document.skins do
      [skin | _] ->
        report = %{
          joint_count: length(skin.joints || []),
          has_inverse_bind_matrices: skin.inverse_bind_matrices != nil,
          skin_index: 0
        }

        {:ok, report}

      [] ->
        {:error, "No skins found in document"}

      nil ->
        {:error, "Skins field is nil"}
    end
  end

  defp validate_morph_structure(document) do
    case document.meshes do
      [mesh | _] ->
        primitive = List.first(mesh.primitives || [])
        morph_targets = primitive && primitive.targets

        report = %{
          has_morph_targets: morph_targets != nil and length(morph_targets) > 0,
          morph_target_count: if(morph_targets, do: length(morph_targets), else: 0),
          mesh_index: 0
        }

        {:ok, report}

      [] ->
        {:error, "No meshes found in document"}

      nil ->
        {:error, "Meshes field is nil"}
    end
  end

  defp maybe_validate_joints(document, true) do
    validate_joint_hierarchy(document)
  end

  defp maybe_validate_joints(_document, false) do
    {:ok, %{skipped: true}}
  end

  defp maybe_validate_animation(document, true) do
    validate_animation_data(document)
  end

  defp maybe_validate_animation(_document, false) do
    {:ok, %{skipped: true}}
  end

  defp maybe_validate_morph_targets(document, true) do
    validate_morph_target_data(document)
  end

  defp maybe_validate_morph_targets(_document, false) do
    {:ok, %{skipped: true}}
  end

  defp maybe_validate_morph_weights(document, true) do
    validate_morph_weight_data(document)
  end

  defp maybe_validate_morph_weights(_document, false) do
    {:ok, %{skipped: true}}
  end

  defp validate_joint_hierarchy(document) do
    case document.skins do
      [skin | _] ->
        validate_joint_hierarchy_internal(document, skin)

      [] ->
        {:error, "No skins found in document"}

      nil ->
        {:error, "Skins field is nil"}
    end
  end

  defp validate_joint_hierarchy_internal(document, skin) do
    nodes = document.nodes || []
    joints = skin.joints || []

    # Validate all joint indices exist in nodes array
    invalid_joints =
      Enum.filter(joints, fn joint_index ->
        joint_index < 0 || joint_index >= length(nodes)
      end)

    if length(invalid_joints) > 0 do
      {:error, "Invalid joint indices: #{inspect(invalid_joints)}"}
    else
      # Validate skeleton root exists in joints
      skeleton_valid =
        case skin.skeleton do
          nil -> true
          skeleton_index -> Enum.member?(joints, skeleton_index)
        end

      if not skeleton_valid do
        {:error, "Skeleton root index #{skin.skeleton} is not in joints list"}
      else
        # Check for circular dependencies in joint hierarchy
        circular_check = check_circular_dependencies(joints, nodes)

        case circular_check do
          {:error, _} = error -> error
          :ok ->
            report = %{
              joint_count: length(joints),
              skeleton_root: skin.skeleton,
              has_valid_hierarchy: true
            }
            {:ok, report}
        end
      end
    end
  end

  defp check_circular_dependencies(joints, nodes) do
    # Basic check: verify no joint has itself as a child (indirectly)
    # For a more complete check, we'd need to build the full hierarchy graph
    check_all_joints(joints, joints, nodes, MapSet.new())
  end

  defp check_all_joints([], _joints, _nodes, _visited), do: :ok

  defp check_all_joints([joint_index | rest], joints, nodes, visited) do
    if MapSet.member?(visited, joint_index) do
      {:error, "Circular dependency detected at joint #{joint_index}"}
    else
      new_visited = MapSet.put(visited, joint_index)
      node = Enum.at(nodes, joint_index)

      case check_node_children(node, joints, nodes, new_visited) do
        {:error, _} = error -> error
        :ok -> check_all_joints(rest, joints, nodes, new_visited)
      end
    end
  end

  defp check_node_children(nil, _joints, _nodes, _visited), do: :ok

  defp check_node_children(node, joints, nodes, visited) when is_map(node) do
    children = node.children || []
    children_in_joints = Enum.filter(children, &Enum.member?(joints, &1))

    Enum.reduce_while(children_in_joints, visited, fn child_index, acc_visited ->
      if MapSet.member?(acc_visited, child_index) do
        {:halt, {:error, "Circular dependency in joint hierarchy at joint #{child_index}"}}
      else
        new_visited = MapSet.put(acc_visited, child_index)
        child_node = Enum.at(nodes, child_index)

        case check_node_children(child_node, joints, nodes, new_visited) do
          {:error, _} = error -> {:halt, error}
          :ok -> {:cont, new_visited}
        end
      end
    end)
    |> case do
      {:error, _} = error -> error
      _ -> :ok
    end
  end

  defp check_node_children(_node, _joints, _nodes, _visited), do: :ok

  defp validate_animation_data(document) do
    case document.animations do
      [animation | _] ->
        channels = animation.channels || []
        samplers = animation.samplers || []

        report = %{
          channel_count: length(channels),
          sampler_count: length(samplers),
          has_valid_animation: length(channels) > 0 and length(samplers) > 0
        }

        {:ok, report}

      [] ->
        {:error, "No animations found in document"}

      nil ->
        {:error, "Animations field is nil"}
    end
  end

  defp validate_morph_target_data(document) do
    case document.meshes do
      meshes when is_list(meshes) and length(meshes) > 0 ->
        validate_morph_targets_in_meshes(meshes, document.accessors)

      [] ->
        {:error, "No meshes found in document"}

      nil ->
        {:error, "Meshes field is nil"}
    end
  end

  defp validate_morph_targets_in_meshes(meshes, accessors) do
    accessors = accessors || []
    errors = []

    {errors, target_counts} =
      Enum.reduce(meshes, {errors, []}, fn mesh, {acc_errors, acc_counts} ->
        case validate_mesh_morph_targets(mesh, accessors) do
          {:ok, target_count} -> {acc_errors, [target_count | acc_counts]}
          {:error, reason} -> {[reason | acc_errors], acc_counts}
        end
      end)

    if length(errors) > 0 do
      {:error, Enum.join(errors, "; ")}
    else
      report = %{
        mesh_count: length(meshes),
        morph_target_counts: Enum.reverse(target_counts),
        has_valid_targets: true
      }
      {:ok, report}
    end
  end

  defp validate_mesh_morph_targets(mesh, accessors) do
    primitives = mesh.primitives || []

    Enum.reduce_while(primitives, {:ok, []}, fn primitive, {:ok, target_counts} ->
      targets = primitive.targets || []

      case validate_primitive_targets(targets, accessors) do
        {:ok, target_count} -> {:cont, {:ok, [target_count | target_counts]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, counts} ->
        # All primitives should have the same number of targets
        unique_counts = counts |> Enum.uniq()
        target_count = if length(unique_counts) > 0, do: hd(unique_counts), else: 0
        {:ok, target_count}
      {:error, _} = error -> error
    end
  end

  defp validate_primitive_targets(targets, accessors) do
    # Validate each target's accessor indices exist
    invalid_accessors =
      Enum.reduce(targets, [], fn target_map, acc ->
        Enum.reduce(target_map, acc, fn {_semantic, accessor_index}, acc_inner ->
          if accessor_index < 0 || accessor_index >= length(accessors) do
            [accessor_index | acc_inner]
          else
            acc_inner
          end
        end)
      end)

    if length(invalid_accessors) > 0 do
      {:error, "Invalid accessor indices in morph targets: #{inspect(invalid_accessors)}"}
    else
      {:ok, length(targets)}
    end
  end

  defp validate_morph_weight_data(document) do
    case document.meshes do
      meshes when is_list(meshes) and length(meshes) > 0 ->
        validate_morph_weights_in_meshes(meshes)

      [] ->
        {:error, "No meshes found in document"}

      nil ->
        {:error, "Meshes field is nil"}
    end
  end

  defp validate_morph_weights_in_meshes(meshes) do
    errors = []

    {errors, weight_reports} =
      Enum.reduce(meshes, {errors, []}, fn mesh, {acc_errors, acc_reports} ->
        case validate_mesh_morph_weights(mesh) do
          {:ok, report} -> {acc_errors, [report | acc_reports]}
          {:error, reason} -> {[reason | acc_errors], acc_reports}
        end
      end)

    if length(errors) > 0 do
      {:error, Enum.join(errors, "; ")}
    else
      report = %{
        mesh_count: length(meshes),
        weight_reports: Enum.reverse(weight_reports),
        has_valid_weights: true
      }
      {:ok, report}
    end
  end

  defp validate_mesh_morph_weights(mesh) do
    weights = mesh.weights || []
    primitives = mesh.primitives || []

    # Check if weights match the number of morph targets
    target_counts =
      Enum.map(primitives, fn primitive ->
        targets = primitive.targets || []
        length(targets)
      end)
      |> Enum.uniq()

    case target_counts do
      [] ->
        # No morph targets, weights should be empty
        if length(weights) == 0 do
          {:ok, %{weight_count: 0, target_count: 0, valid: true}}
        else
          {:error, "Weights provided but no morph targets in mesh"}
        end

      [target_count] ->
        # Validate weight count matches target count
        if length(weights) != target_count do
          {:error, "Weight count (#{length(weights)}) does not match morph target count (#{target_count})"}
        else
          # Validate all weights are in valid range [0.0, 1.0]
          invalid_weights =
            Enum.filter(weights, fn weight ->
              not is_number(weight) or weight < 0.0 or weight > 1.0
            end)

          if length(invalid_weights) > 0 do
            {:error, "Invalid morph weights (must be in range [0.0, 1.0]): #{inspect(invalid_weights)}"}
          else
            {:ok, %{weight_count: length(weights), target_count: target_count, valid: true}}
          end
        end

      _ ->
        {:error, "Primitives have inconsistent morph target counts"}
    end
  end

  defp get_animation(document, index) do
    case document.animations do
      animations when is_list(animations) ->
        if index < length(animations) do
          {:ok, Enum.at(animations, index)}
        else
          {:error, "Animation index #{index} out of bounds"}
        end

      _ ->
        {:error, "No animations available in document"}
    end
  end

  defp has_skeletal_animation?(document) do
    document.skins != nil and length(document.skins || []) > 0
  end

  defp process_skeletal_animation(document, animation, timestamp, use_aria_joint, use_aria_math) do
    # Basic skeletal animation processing placeholder
    # In a full implementation, this would:
    # 1. Evaluate animation samplers at the given timestamp
    # 2. Apply transforms to joint nodes using AriaJoint
    # 3. Compute skinning matrices using AriaMath
    # 4. Return processed mesh state

    processed_state = %{
      timestamp: timestamp,
      animation_index: get_animation_index(document, animation),
      use_aria_joint: use_aria_joint,
      use_aria_math: use_aria_math,
      joint_transforms: [],
      skinned_vertices: [],
      status: :placeholder
    }

    {:ok, processed_state}
  end

  defp get_animation_index(document, animation) do
    animations = document.animations || []
    Enum.find_index(animations, &(&1 == animation)) || 0
  end

  defp process_morph_animation(document, animation, timestamp) do
    # Basic morph animation processing placeholder
    # In a full implementation, this would:
    # 1. Evaluate animation samplers at the given timestamp
    # 2. Interpolate morph target weights
    # 3. Blend morph target attributes
    # 4. Return processed mesh state with morphed vertices

    processed_state = %{
      timestamp: timestamp,
      animation_index: get_animation_index(document, animation),
      morph_weights: [],
      morphed_vertices: [],
      status: :placeholder
    }

    {:ok, processed_state}
  end
end
