# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.DataTypes do
  @moduledoc """
  Data type and enum validation for glTF 2.0 documents.

  This module validates that all enum values and data types conform to the
  glTF 2.0 specification, including accessor types, animation interpolations,
  material alpha modes, camera types, primitive modes, and sampler filters.
  """

  alias AriaGltf.Validation.Context

  @doc """
  Validates all data types and enums in the document.

  Checks accessor types, animation interpolations, material alpha modes,
  camera types, primitive modes, and sampler filters.
  """
  @spec validate(Context.t(), AriaGltf.Document.t()) :: Context.t()
  def validate(context, document) do
    context
    |> validate_accessor_types(document.accessors || [])
    |> validate_animation_interpolations(document.animations || [])
    |> validate_material_alpha_modes(document.materials || [])
    |> validate_camera_types(document.cameras || [])
    |> validate_primitive_modes(document.meshes || [])
    |> validate_sampler_filters(document.samplers || [])
  end

  # Accessor validation
  @valid_component_types [5120, 5121, 5122, 5123, 5125, 5126]
  @valid_accessor_types ["SCALAR", "VEC2", "VEC3", "VEC4", "MAT2", "MAT3", "MAT4"]
  @valid_accessor_type_atoms [:scalar, :vec2, :vec3, :vec4, :mat2, :mat3, :mat4]

  defp validate_accessor_types(context, accessors) do
    Enum.with_index(accessors)
    |> Enum.reduce(context, fn {accessor, index}, ctx ->
      ctx
      |> validate_accessor_component_type(accessor, index)
      |> validate_accessor_type_enum(accessor, index)
    end)
  end

  defp validate_accessor_component_type(context, %{component_type: component_type}, _index)
       when component_type in @valid_component_types do
    context
  end

  defp validate_accessor_component_type(context, %{component_type: component_type}, index) do
    Context.add_error(
      context,
      {:accessor, index},
      "Invalid componentType: #{component_type}. Must be one of #{inspect(@valid_component_types)}"
    )
  end

  defp validate_accessor_component_type(context, _, _), do: context

  defp validate_accessor_type_enum(context, %{type: type}, _index)
       when type in @valid_accessor_types or type in @valid_accessor_type_atoms do
    context
  end

  defp validate_accessor_type_enum(context, %{type: type}, index) do
    Context.add_error(
      context,
      {:accessor, index},
      "Invalid accessor type: #{inspect(type)}. Must be one of #{inspect(@valid_accessor_types)}"
    )
  end

  defp validate_accessor_type_enum(context, _, _), do: context

  # Animation interpolation validation
  @valid_interpolations ["LINEAR", "STEP", "CUBICSPLINE"]
  @valid_interpolation_atoms [:linear, :step, :cubicspline]

  defp validate_animation_interpolations(context, animations) do
    Enum.with_index(animations)
    |> Enum.reduce(context, fn {animation, anim_index}, ctx ->
      case animation do
        %{samplers: samplers} when is_list(samplers) ->
          Enum.with_index(samplers)
          |> Enum.reduce(ctx, fn {sampler, samp_index}, acc ->
            validate_sampler_interpolation(acc, sampler, {anim_index, samp_index})
          end)

        _ ->
          ctx
      end
    end)
  end

  defp validate_sampler_interpolation(context, %{interpolation: interpolation}, {_anim_index, _samp_index})
       when interpolation in @valid_interpolations or interpolation in @valid_interpolation_atoms do
    context
  end

  defp validate_sampler_interpolation(context, %{interpolation: interpolation}, {anim_index, samp_index}) do
    Context.add_error(
      context,
      {:animation, anim_index, :sampler, samp_index},
      "Invalid interpolation: #{inspect(interpolation)}. Must be one of #{inspect(@valid_interpolations)}"
    )
  end

  defp validate_sampler_interpolation(context, _, _), do: context

  # Material alpha mode validation
  @valid_alpha_modes ["OPAQUE", "MASK", "BLEND"]
  @valid_alpha_mode_atoms [:opaque, :mask, :blend]

  defp validate_material_alpha_modes(context, materials) do
    Enum.with_index(materials)
    |> Enum.reduce(context, fn {material, index}, ctx ->
      case material do
        %{alpha_mode: alpha_mode}
        when alpha_mode in @valid_alpha_modes or alpha_mode in @valid_alpha_mode_atoms ->
          ctx

        %{alpha_mode: alpha_mode} ->
          Context.add_error(
            ctx,
            {:material, index},
            "Invalid alphaMode: #{inspect(alpha_mode)}. Must be one of #{inspect(@valid_alpha_modes)}"
          )

        _ ->
          ctx
      end
    end)
  end

  # Camera type validation
  @valid_camera_types ["perspective", "orthographic"]
  @valid_camera_type_atoms [:perspective, :orthographic]

  defp validate_camera_types(context, cameras) do
    Enum.with_index(cameras)
    |> Enum.reduce(context, fn {camera, index}, ctx ->
      case camera do
        %{type: type} when type in @valid_camera_types or type in @valid_camera_type_atoms ->
          ctx

        %{type: type} ->
          Context.add_error(
            ctx,
            {:camera, index},
            "Invalid camera type: #{inspect(type)}. Must be one of #{inspect(@valid_camera_types)}"
          )

        _ ->
          Context.add_error(ctx, {:camera, index}, "Camera type is required")
      end
    end)
  end

  # Primitive mode validation
  @valid_primitive_modes [0, 1, 2, 3, 4, 5, 6]

  defp validate_primitive_modes(context, meshes) do
    Enum.with_index(meshes)
    |> Enum.reduce(context, fn {mesh, mesh_index}, ctx ->
      case mesh do
        %{primitives: primitives} when is_list(primitives) ->
          Enum.with_index(primitives)
          |> Enum.reduce(ctx, fn {primitive, prim_index}, acc ->
            validate_primitive_mode(acc, primitive, {mesh_index, prim_index})
          end)

        _ ->
          ctx
      end
    end)
  end

  defp validate_primitive_mode(context, %{mode: mode}, {_mesh_index, _prim_index})
       when mode in @valid_primitive_modes do
    context
  end

  defp validate_primitive_mode(context, %{mode: mode}, {mesh_index, prim_index}) do
    Context.add_error(
      context,
      {:mesh, mesh_index, :primitive, prim_index},
      "Invalid primitive mode: #{mode}. Must be one of #{inspect(@valid_primitive_modes)}"
    )
  end

  defp validate_primitive_mode(context, _, _), do: context

  # Sampler filter/wrap validation
  @valid_mag_filters [9728, 9729] # NEAREST, LINEAR
  @valid_min_filters [9728, 9729, 9984, 9985, 9986, 9987] # NEAREST, LINEAR, NEAREST_MIPMAP_NEAREST, LINEAR_MIPMAP_NEAREST, NEAREST_MIPMAP_LINEAR, LINEAR_MIPMAP_LINEAR
  @valid_wrap_modes [33071, 33648, 10_497] # CLAMP_TO_EDGE, MIRRORED_REPEAT, REPEAT

  defp validate_sampler_filters(context, samplers) do
    Enum.with_index(samplers)
    |> Enum.reduce(context, fn {sampler, index}, ctx ->
      ctx
      |> validate_sampler_mag_filter(sampler, index)
      |> validate_sampler_min_filter(sampler, index)
      |> validate_sampler_wrap_s(sampler, index)
      |> validate_sampler_wrap_t(sampler, index)
    end)
  end

  defp validate_sampler_mag_filter(context, %{mag_filter: nil}, _), do: context

  defp validate_sampler_mag_filter(context, %{mag_filter: mag_filter}, _index)
       when mag_filter in @valid_mag_filters do
    context
  end

  defp validate_sampler_mag_filter(context, %{mag_filter: mag_filter}, index) do
    Context.add_error(
      context,
      {:sampler, index},
      "Invalid magFilter: #{mag_filter}. Must be one of #{inspect(@valid_mag_filters)}"
    )
  end

  defp validate_sampler_mag_filter(context, _, _), do: context

  defp validate_sampler_min_filter(context, %{min_filter: nil}, _), do: context

  defp validate_sampler_min_filter(context, %{min_filter: min_filter}, _index)
       when min_filter in @valid_min_filters do
    context
  end

  defp validate_sampler_min_filter(context, %{min_filter: min_filter}, index) do
    Context.add_error(
      context,
      {:sampler, index},
      "Invalid minFilter: #{min_filter}. Must be one of #{inspect(@valid_min_filters)}"
    )
  end

  defp validate_sampler_min_filter(context, _, _), do: context

  defp validate_sampler_wrap_s(context, %{wrap_s: wrap_s}, _index)
       when wrap_s in @valid_wrap_modes do
    context
  end

  defp validate_sampler_wrap_s(context, %{wrap_s: wrap_s}, index) do
    Context.add_error(
      context,
      {:sampler, index},
      "Invalid wrapS: #{wrap_s}. Must be one of #{inspect(@valid_wrap_modes)}"
    )
  end

  defp validate_sampler_wrap_s(context, _, _), do: context

  defp validate_sampler_wrap_t(context, %{wrap_t: wrap_t}, _index)
       when wrap_t in @valid_wrap_modes do
    context
  end

  defp validate_sampler_wrap_t(context, %{wrap_t: wrap_t}, index) do
    Context.add_error(
      context,
      {:sampler, index},
      "Invalid wrapT: #{wrap_t}. Must be one of #{inspect(@valid_wrap_modes)}"
    )
  end

  defp validate_sampler_wrap_t(context, _, _), do: context
end

