# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.Vrm.Validators.Collider do
  @moduledoc """
  VRM collider (spring bone collider) validation.

  Validates VRM spring bone colliders including sphere, capsule, and plane shapes.
  """

  alias AriaGltf.{Document, Validation.Context}

  @doc """
  Validates VRM colliders.
  """
  @spec validate(Context.t(), map(), Document.t()) :: Context.t()
  def validate(context, spring_bone, document) when is_map(spring_bone) do
    colliders = Map.get(spring_bone, "colliders")

    if colliders && is_list(colliders) do
      Enum.with_index(colliders)
      |> Enum.reduce(context, fn {collider, index}, ctx ->
        validate_collider(ctx, collider, index, document)
      end)
    else
      context
    end
  end

  def validate(context, _, _), do: context

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
end

