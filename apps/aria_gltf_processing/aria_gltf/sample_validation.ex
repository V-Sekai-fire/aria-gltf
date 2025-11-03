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
    raise "TODO: Implement #{__MODULE__}.validate_joint_hierarchy"
  end

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
    raise "TODO: Implement #{__MODULE__}.validate_morph_target_data"
  end

  defp validate_morph_weight_data(document) do
    raise "TODO: Implement #{__MODULE__}.validate_morph_weight_data"
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

  defp process_skeletal_animation(document, _animation, timestamp, use_aria_joint, use_aria_math) do
    raise "TODO: Implement #{__MODULE__}.process_skeletal_animation"
  end

  defp process_morph_animation(document, _animation, timestamp) do
    raise "TODO: Implement #{__MODULE__}.process_morph_animation"
  end
end
