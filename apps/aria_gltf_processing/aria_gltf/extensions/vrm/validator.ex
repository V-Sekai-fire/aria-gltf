# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.Vrm.Validator do
  @moduledoc """
  Validation for VRM 1.0 extension (VRMC_vrm).

  Validates VRM 1.0 specification compliance including:
  - Meta information (title, author, contact, etc.)
  - Humanoid bone structure and mappings
  - Expressions (blend shapes)
  - Collision detection (spring bone colliders)
  - VRM-specific constraints and requirements

  Reference: VRM 1.0 Specification
  https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_vrm-1.0
  """

  alias AriaGltf.Document
  alias AriaGltf.Validation.Context

  @vrm_extension_name "VRMC_vrm"

  @doc """
  Validates VRM 1.0 extension data in a glTF document.

  ## Parameters

  - `context`: Validation context containing the document

  ## Returns

  Updated context with VRM validation errors/warnings

  ## Examples

      context = AriaGltf.Extensions.Vrm.Validator.validate(context)
  """
  @spec validate(Context.t()) :: Context.t()
  def validate(%Context{document: document} = context) do
    # Check if VRM extension is used
    extensions_used = document.extensions_used || []

    if @vrm_extension_name in extensions_used do
      context
      |> validate_vrm_extension_present(document)
      |> validate_vrm_meta(document)
      |> validate_vrm_humanoid(document)
      |> validate_vrm_expressions(document)
      |> validate_vrm_colliders(document)
    else
      context
    end
  end

  # Validate that VRM extension is present in document extensions
  defp validate_vrm_extension_present(context, %Document{extensions: extensions}) do
    if extensions && Map.has_key?(extensions, @vrm_extension_name) do
      context
    else
      Context.add_error(
        context,
        :vrm_extension,
        "VRMC_vrm extension declared in extensionsUsed but not found in extensions"
      )
    end
  end

  defp validate_vrm_extension_present(context, _), do: context

  # Validate VRM meta information
  defp validate_vrm_meta(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      meta = Map.get(vrm_ext, "meta")

      if meta do
        context
        |> validate_meta_title(meta)
        |> validate_meta_version(meta)
        |> validate_meta_authors(meta)
        |> validate_meta_copyright_information(meta)
        |> validate_meta_contact_information(meta)
        |> validate_meta_reference(meta)
        |> validate_meta_thumbnail_image(meta, context.document)
      else
        Context.add_warning(
          context,
          :vrm_meta,
          "VRM extension found but meta field is missing (optional but recommended)"
        )
      end
    else
      context
    end
  end

  defp validate_vrm_meta(context, _), do: context

  # Validate meta title
  defp validate_meta_title(context, meta) do
    title = Map.get(meta, "title")

    if title && is_binary(title) && String.length(title) > 0 do
      context
    else
      Context.add_warning(
        context,
        :vrm_meta,
        "VRM meta.title is missing or empty (optional but recommended)"
      )
    end
  end

  # Validate meta version
  defp validate_meta_version(context, meta) do
    version = Map.get(meta, "version")

    if version && is_binary(version) do
      context
    else
      Context.add_warning(
        context,
        :vrm_meta,
        "VRM meta.version is missing (optional but recommended)"
      )
    end
  end

  # Validate meta authors array
  defp validate_meta_authors(context, meta) do
    authors = Map.get(meta, "authors")

    if authors do
      if is_list(authors) && Enum.all?(authors, &is_binary/1) do
        context
      else
        Context.add_error(
          context,
          :vrm_meta,
          "VRM meta.authors must be an array of strings"
        )
      end
    else
      context
    end
  end

  # Validate copyright information
  defp validate_meta_copyright_information(context, meta) do
    copyright_information = Map.get(meta, "copyrightInformation")

    if copyright_information && is_binary(copyright_information) do
      context
    else
      context
    end
  end

  # Validate contact information
  defp validate_meta_contact_information(context, meta) do
    contact_information = Map.get(meta, "contactInformation")

    if contact_information do
      if is_list(contact_information) && Enum.all?(contact_information, &is_binary/1) do
        context
      else
        Context.add_error(
          context,
          :vrm_meta,
          "VRM meta.contactInformation must be an array of strings"
        )
      end
    else
      context
    end
  end

  # Validate reference
  defp validate_meta_reference(context, meta) do
    reference = Map.get(meta, "reference")

    if reference && is_binary(reference) do
      context
    else
      context
    end
  end

  # Validate thumbnail image index
  defp validate_meta_thumbnail_image(context, meta, %Document{images: images}) do
    thumbnail_image = Map.get(meta, "thumbnailImage")

    if thumbnail_image do
      images_count = length(images || [])

      if is_integer(thumbnail_image) && thumbnail_image >= 0 && thumbnail_image < images_count do
        context
      else
        Context.add_error(
          context,
          :vrm_meta,
          "VRM meta.thumbnailImage index #{thumbnail_image} is out of bounds (max: #{images_count - 1})"
        )
      end
    else
      context
    end
  end

  defp validate_meta_thumbnail_image(context, _, _), do: context

  # Validate VRM humanoid bone structure
  defp validate_vrm_humanoid(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      humanoid = Map.get(vrm_ext, "humanoid")

      if humanoid do
        context
        |> validate_humanoid_human_bones(humanoid, context.document)
        |> validate_humanoid_hips_bone_required(humanoid)
      else
        Context.add_warning(
          context,
          :vrm_humanoid,
          "VRM humanoid field is missing (required for VRM compliance)"
        )
      end
    else
      context
    end
  end

  defp validate_vrm_humanoid(context, _), do: context

  # Validate humanoid humanBones structure
  defp validate_humanoid_human_bones(context, humanoid, %Document{nodes: nodes}) do
    human_bones = Map.get(humanoid, "humanBones")

    if human_bones && is_map(human_bones) do
      nodes_count = length(nodes || [])

      Enum.reduce(human_bones, context, fn {bone_name, bone_data}, ctx ->
        validate_human_bone(ctx, bone_name, bone_data, nodes_count)
      end)
    else
      Context.add_error(
        context,
        :vrm_humanoid,
        "VRM humanoid.humanBones must be an object"
      )
    end
  end

  defp validate_humanoid_human_bones(context, _, _), do: context

  # Validate individual human bone
  defp validate_human_bone(context, bone_name, bone_data, nodes_count) do
    node_index = Map.get(bone_data, "node")

    if is_integer(node_index) && node_index >= 0 && node_index < nodes_count do
      context
    else
      Context.add_error(
        context,
        :vrm_humanoid,
        "VRM humanoid.humanBones.#{bone_name}.node index #{node_index} is out of bounds (max: #{nodes_count - 1})"
      )
    end
  end

  # Validate that hips bone is required
  defp validate_humanoid_hips_bone_required(context, humanoid) do
    human_bones = Map.get(humanoid, "humanBones")

    if human_bones && Map.has_key?(human_bones, "hips") do
      context
    else
      Context.add_error(
        context,
        :vrm_humanoid,
        "VRM humanoid.humanBones.hips is required"
      )
    end
  end

  # Validate VRM expressions (blend shapes)
  defp validate_vrm_expressions(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      expressions = Map.get(vrm_ext, "expressions")

      if expressions && is_map(expressions) do
        presets = Map.get(expressions, "preset")
        custom = Map.get(expressions, "custom")

        context
        |> validate_expression_presets(presets)
        |> validate_expression_custom(custom)
      else
        context
      end
    else
      context
    end
  end

  defp validate_vrm_expressions(context, _), do: context

  # Validate expression presets
  defp validate_expression_presets(context, presets) when is_map(presets) do
    valid_presets = [
      "happy",
      "angry",
      "sad",
      "relaxed",
      "surprised",
      "aa",
      "ih",
      "ou",
      "ee",
      "oh",
      "blink",
      "blinkLeft",
      "blinkRight",
      "lookUp",
      "lookDown",
      "lookLeft",
      "lookRight"
    ]

    Enum.reduce(presets, context, fn {preset_name, preset_data}, ctx ->
      if preset_name in valid_presets do
        validate_expression_data(ctx, preset_name, preset_data)
      else
        Context.add_warning(
          ctx,
          :vrm_expressions,
          "Unknown VRM expression preset: #{preset_name}"
        )
      end
    end)
  end

  defp validate_expression_presets(context, _), do: context

  # Validate custom expressions
  defp validate_expression_custom(context, custom) when is_map(custom) do
    Enum.reduce(custom, context, fn {custom_name, custom_data}, ctx ->
      validate_expression_data(ctx, custom_name, custom_data)
    end)
  end

  defp validate_expression_custom(context, _), do: context

  # Validate expression data structure
  defp validate_expression_data(context, expression_name, expression_data) do
    is_binary = Map.get(expression_data, "isBinary")

    if is_boolean(is_binary) do
      context
    else
      Context.add_error(
        context,
        :vrm_expressions,
        "VRM expressions.#{expression_name}.isBinary must be a boolean"
      )
    end
  end

  # Validate VRM colliders (spring bone colliders)
  defp validate_vrm_colliders(context, %Document{extensions: extensions}) do
    vrm_ext = get_vrm_extension(extensions)

    if vrm_ext do
      spring_bone = Map.get(vrm_ext, "springBone")

      if spring_bone do
        colliders = Map.get(spring_bone, "colliders")

        if colliders && is_list(colliders) do
          Enum.with_index(colliders)
          |> Enum.reduce(context, fn {collider, index}, ctx ->
            validate_collider(ctx, collider, index, context.document)
          end)
        else
          context
        end
      else
        context
      end
    else
      context
    end
  end

  defp validate_vrm_colliders(context, _), do: context

  # Validate individual collider
  defp validate_collider(context, collider, index, %Document{nodes: nodes}) do
    nodes_count = length(nodes || [])

    node_index = Map.get(collider, "node")

    context =
      if is_integer(node_index) && node_index >= 0 && node_index < nodes_count do
        context
      else
        Context.add_error(
          context,
          :vrm_colliders,
          "VRM springBone.colliders[#{index}].node index #{inspect(node_index)} is out of bounds (max: #{nodes_count - 1})"
        )
      end

    shape = Map.get(collider, "shape")

    if shape && is_map(shape) do
      validate_collider_shape(context, shape, index)
    else
      Context.add_error(
        context,
        :vrm_colliders,
        "VRM springBone.colliders[#{index}].shape is required"
      )
    end
  end

  # Validate collider shape (sphere, capsule, or plane)
  defp validate_collider_shape(context, shape, collider_index) do
    shape_type = Map.keys(shape) |> List.first()

    case shape_type do
      "sphere" ->
        validate_sphere_collider(context, Map.get(shape, "sphere"), collider_index)

      "capsule" ->
        validate_capsule_collider(context, Map.get(shape, "capsule"), collider_index)

      "plane" ->
        validate_plane_collider(context, Map.get(shape, "plane"), collider_index)

      _ ->
        Context.add_error(
          context,
          :vrm_colliders,
          "VRM springBone.colliders[#{collider_index}].shape must be one of: sphere, capsule, plane"
        )
    end
  end

  # Validate sphere collider
  defp validate_sphere_collider(context, sphere, collider_index) when is_map(sphere) do
    offset = Map.get(sphere, "offset")
    radius = Map.get(sphere, "radius")

    context =
      if offset && is_list(offset) && length(offset) == 3 &&
           Enum.all?(offset, &is_number/1) do
        context
      else
        Context.add_error(
          context,
          :vrm_colliders,
          "VRM springBone.colliders[#{collider_index}].shape.sphere.offset must be [x, y, z] array"
        )
      end

    if radius && is_number(radius) && radius > 0 do
      context
    else
      Context.add_error(
        context,
        :vrm_colliders,
        "VRM springBone.colliders[#{collider_index}].shape.sphere.radius must be a positive number"
      )
    end
  end

  defp validate_sphere_collider(context, _, collider_index) do
    Context.add_error(
      context,
      :vrm_colliders,
      "VRM springBone.colliders[#{collider_index}].shape.sphere is required"
    )
  end

  # Validate capsule collider
  defp validate_capsule_collider(context, capsule, collider_index) when is_map(capsule) do
    offset = Map.get(capsule, "offset")
    radius = Map.get(capsule, "radius")
    tail = Map.get(capsule, "tail")

    context =
      if offset && is_list(offset) && length(offset) == 3 &&
           Enum.all?(offset, &is_number/1) do
        context
      else
        Context.add_error(
          context,
          :vrm_colliders,
          "VRM springBone.colliders[#{collider_index}].shape.capsule.offset must be [x, y, z] array"
        )
      end

    context =
      if tail && is_list(tail) && length(tail) == 3 && Enum.all?(tail, &is_number/1) do
        context
      else
        Context.add_error(
          context,
          :vrm_colliders,
          "VRM springBone.colliders[#{collider_index}].shape.capsule.tail must be [x, y, z] array"
        )
      end

    if radius && is_number(radius) && radius > 0 do
      context
    else
      Context.add_error(
        context,
        :vrm_colliders,
        "VRM springBone.colliders[#{collider_index}].shape.capsule.radius must be a positive number"
      )
    end
  end

  defp validate_capsule_collider(context, _, collider_index) do
    Context.add_error(
      context,
      :vrm_colliders,
      "VRM springBone.colliders[#{collider_index}].shape.capsule is required"
    )
  end

  # Validate plane collider
  defp validate_plane_collider(context, plane, collider_index) when is_map(plane) do
    offset = Map.get(plane, "offset")
    normal = Map.get(plane, "normal")

    context =
      if offset && is_list(offset) && length(offset) == 3 &&
           Enum.all?(offset, &is_number/1) do
        context
      else
        Context.add_error(
          context,
          :vrm_colliders,
          "VRM springBone.colliders[#{collider_index}].shape.plane.offset must be [x, y, z] array"
        )
      end

    if normal && is_list(normal) && length(normal) == 3 && Enum.all?(normal, &is_number/1) do
      context
    else
      Context.add_error(
        context,
        :vrm_colliders,
        "VRM springBone.colliders[#{collider_index}].shape.plane.normal must be [x, y, z] array"
      )
    end
  end

  defp validate_plane_collider(context, _, collider_index) do
    Context.add_error(
      context,
      :vrm_colliders,
      "VRM springBone.colliders[#{collider_index}].shape.plane is required"
    )
  end

  # Helper: Get VRM extension from document extensions
  defp get_vrm_extension(nil), do: nil
  defp get_vrm_extension(extensions), do: Map.get(extensions, @vrm_extension_name)
end

