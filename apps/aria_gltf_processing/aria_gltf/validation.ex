# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation do
  @moduledoc """
  Comprehensive validation framework for glTF 2.0 specification compliance.

  This module provides validation functions for glTF documents, ensuring they
  conform to the glTF 2.0 specification and reporting detailed errors and warnings.
  """

  alias AriaGltf.{Document, Asset}
  alias AriaGltf.Validation.{Report, Context, SchemaValidator, DataTypes, ExtensionRouter}

  @type validation_result :: {:ok, Document.t()} | {:error, Report.t()}
  @type validation_mode :: :strict | :permissive | :warning_only

  @doc """
  Validates a glTF document comprehensively.

  ## Options

  - `:mode` - Validation mode `:strict` (default), `:permissive`, or `:warning_only`
  - `:check_indices` - Whether to validate index references (default: true)
  - `:check_extensions` - Whether to validate extensions (default: true)
  - `:check_schema` - Whether to validate against JSON schema (default: true)
  - `:overrides` - List of validation checks to override, can be:
    - `:buffer_view_indices` - Skip strict bufferView index validation
    - `:accessor_buffer_views` - Allow accessors without bufferView references
    - `:strict_bounds_checking` - Downgrade bounds errors to warnings

  ## Examples

      iex> AriaGltf.Validation.validate(document)
      {:ok, document}

      iex> AriaGltf.Validation.validate(invalid_document)
      {:error, %AriaGltf.Validation.Report{errors: [...]}}

      iex> AriaGltf.Validation.validate(document, overrides: [:buffer_view_indices])
      {:ok, document}
  """
  @spec validate(Document.t(), keyword()) :: validation_result()
  def validate(%Document{} = document, opts \\ []) do
    mode = Keyword.get(opts, :mode, :strict)
    check_indices = Keyword.get(opts, :check_indices, true)
    check_extensions = Keyword.get(opts, :check_extensions, true)
    check_schema = Keyword.get(opts, :check_schema, true)
    overrides = Keyword.get(opts, :overrides, [])

    context = Context.new(document, mode, overrides)

    context
    |> validate_asset()
    |> validate_scene_references()
    |> then(fn ctx -> if check_indices, do: validate_index_references(ctx), else: ctx end)
    |> then(fn ctx -> if check_extensions, do: validate_extensions(ctx), else: ctx end)
    |> then(fn ctx -> if check_schema, do: validate_schema(ctx), else: ctx end)
    |> validate_arrays()
    |> validate_required_fields()
    |> validate_data_types()
    |> finalize_validation()
  end

  @doc """
  Validates specific glTF data types and constraints.
  """
  @spec validate_data_types(Context.t()) :: Context.t()
  def validate_data_types(%Context{document: document} = context) do
    DataTypes.validate(context, document)
  end

  # Asset validation
  defp validate_asset(%Context{document: %{asset: asset}} = context) do
    case validate_asset_version(asset) do
      :ok -> context
      {:error, error} -> Context.add_error(context, :asset, error)
    end
  end

  defp validate_asset_version(%Asset{version: version}) when is_binary(version) do
    case version do
      "2.0" -> :ok
      _ -> {:error, "Invalid glTF version: #{version}. Only version 2.0 is supported"}
    end
  end

  defp validate_asset_version(_), do: {:error, "Asset version is required and must be a string"}

  # Scene reference validation
  defp validate_scene_references(%Context{document: document} = context) do
    case document.scene do
      nil ->
        context

      scene_index when is_integer(scene_index) ->
        if scene_index >= 0 and scene_index < length(document.scenes || []) do
          context
        else
          Context.add_error(context, :scene, "Scene index #{scene_index} is out of bounds")
        end

      _ ->
        Context.add_error(context, :scene, "Scene index must be a non-negative integer")
    end
  end

  # Index reference validation
  defp validate_index_references(%Context{document: document} = context) do
    context
    |> validate_node_indices(document.nodes || [])
    |> validate_mesh_indices(document.meshes || [])
    |> validate_material_indices(document.materials || [])
    |> validate_texture_indices(document.textures || [])
    |> validate_accessor_indices(document.accessors || [])
    |> validate_buffer_view_indices(document.buffer_views || [])
    |> validate_buffer_indices(document.buffers || [])
  end

  defp validate_node_indices(context, nodes) do
    Enum.with_index(nodes)
    |> Enum.reduce(context, fn {node, index}, ctx ->
      ctx
      |> validate_node_children(node, index, length(nodes))
      |> validate_node_mesh_reference(node, index, context.document.meshes)
      |> validate_node_camera_reference(node, index, context.document.cameras)
      |> validate_node_skin_reference(node, index, context.document.skins)
    end)
  end

  defp validate_node_children(context, %{children: children}, node_index, total_nodes)
       when is_list(children) do
    Enum.reduce(children, context, fn child_index, ctx ->
      if is_integer(child_index) and child_index >= 0 and child_index < total_nodes do
        ctx
      else
        Context.add_error(ctx, {:node, node_index}, "Invalid child node index: #{child_index}")
      end
    end)
  end

  defp validate_node_children(context, _, _, _), do: context

  defp validate_node_mesh_reference(context, %{mesh: mesh_index}, node_index, meshes)
       when is_integer(mesh_index) do
    if mesh_index >= 0 and mesh_index < length(meshes || []) do
      context
    else
      Context.add_error(context, {:node, node_index}, "Invalid mesh index: #{mesh_index}")
    end
  end

  defp validate_node_mesh_reference(context, _, _, _), do: context

  defp validate_node_camera_reference(context, %{camera: camera_index}, node_index, cameras)
       when is_integer(camera_index) do
    if camera_index >= 0 and camera_index < length(cameras || []) do
      context
    else
      Context.add_error(context, {:node, node_index}, "Invalid camera index: #{camera_index}")
    end
  end

  defp validate_node_camera_reference(context, _, _, _), do: context

  defp validate_node_skin_reference(context, %{skin: skin_index}, node_index, skins)
       when is_integer(skin_index) do
    if skin_index >= 0 and skin_index < length(skins || []) do
      context
    else
      Context.add_error(context, {:node, node_index}, "Invalid skin index: #{skin_index}")
    end
  end

  defp validate_node_skin_reference(context, _, _, _), do: context

  defp validate_mesh_indices(context, meshes) do
    Enum.with_index(meshes)
    |> Enum.reduce(context, fn {mesh, index}, ctx ->
      validate_mesh_references(ctx, mesh, index, context.document)
    end)
  end

  defp validate_material_indices(context, materials) do
    Enum.with_index(materials)
    |> Enum.reduce(context, fn {material, index}, ctx ->
      validate_material_references(ctx, material, index, context.document)
    end)
  end

  defp validate_texture_indices(context, textures) do
    Enum.with_index(textures)
    |> Enum.reduce(context, fn {texture, index}, ctx ->
      validate_texture_references(ctx, texture, index, context.document)
    end)
  end

  defp validate_accessor_indices(context, accessors) do
    Enum.with_index(accessors)
    |> Enum.reduce(context, fn {accessor, index}, ctx ->
      validate_accessor_references(ctx, accessor, index, context.document)
    end)
  end

  defp validate_buffer_view_indices(context, buffer_views) do
    Enum.with_index(buffer_views)
    |> Enum.reduce(context, fn {buffer_view, index}, ctx ->
      validate_buffer_view_references(ctx, buffer_view, index, context.document)
    end)
  end

  defp validate_buffer_indices(context, buffers) do
    Enum.with_index(buffers)
    |> Enum.reduce(context, fn {buffer, index}, ctx ->
      validate_buffer_references(ctx, buffer, index)
    end)
  end

  # Individual reference validation functions
  defp validate_mesh_references(context, mesh, mesh_index, document) do
    # Validate material references in primitives
    case mesh do
      %{primitives: primitives} when is_list(primitives) ->
        Enum.with_index(primitives)
        |> Enum.reduce(context, fn {primitive, prim_index}, ctx ->
          validate_primitive_references(ctx, primitive, {mesh_index, prim_index}, document)
        end)

      _ ->
        context
    end
  end

  defp validate_primitive_references(context, primitive, {mesh_index, prim_index}, document) do
    materials = document.materials || []
    accessors = document.accessors || []

    context =
      case primitive do
        %{material: material_index} when is_integer(material_index) ->
          if material_index >= 0 and material_index < length(materials) do
            context
          else
            Context.add_error(
              context,
              {:mesh, mesh_index, :primitive, prim_index},
              "Invalid material index: #{material_index}"
            )
          end

        _ ->
          context
      end

    # Validate accessor references for attributes and indices
    context =
      case primitive do
        %{attributes: attributes} when is_map(attributes) ->
          Enum.reduce(attributes, context, fn {attr_name, accessor_index}, ctx ->
            if is_integer(accessor_index) and accessor_index >= 0 and
                 accessor_index < length(accessors) do
              ctx
            else
              Context.add_error(
                ctx,
                {:mesh, mesh_index, :primitive, prim_index},
                "Invalid accessor index for attribute #{attr_name}: #{accessor_index}"
              )
            end
          end)

        _ ->
          context
      end

    case primitive do
      %{indices: indices_accessor} when is_integer(indices_accessor) ->
        if indices_accessor >= 0 and indices_accessor < length(accessors) do
          context
        else
          Context.add_error(
            context,
            {:mesh, mesh_index, :primitive, prim_index},
            "Invalid indices accessor index: #{indices_accessor}"
          )
        end

      _ ->
        context
    end
  end

  defp validate_material_references(context, material, material_index, document) do
    textures = document.textures || []

    # Validate texture references in material
    context
    |> validate_texture_info_reference(material, :base_color_texture, material_index, textures)
    |> validate_texture_info_reference(
      material,
      :metallic_roughness_texture,
      material_index,
      textures
    )
    |> validate_texture_info_reference(material, :normal_texture, material_index, textures)
    |> validate_texture_info_reference(material, :occlusion_texture, material_index, textures)
    |> validate_texture_info_reference(material, :emissive_texture, material_index, textures)
  end

  defp validate_texture_info_reference(context, material, field, material_index, textures) do
    case Map.get(material, field) do
      %{index: texture_index} when is_integer(texture_index) ->
        if texture_index >= 0 and texture_index < length(textures) do
          context
        else
          Context.add_error(
            context,
            {:material, material_index},
            "Invalid texture index for #{field}: #{texture_index}"
          )
        end

      _ ->
        context
    end
  end

  defp validate_texture_references(context, texture, texture_index, document) do
    images = document.images || []
    samplers = document.samplers || []

    context =
      case texture do
        %{source: image_index} when is_integer(image_index) ->
          if image_index >= 0 and image_index < length(images) do
            context
          else
            Context.add_error(
              context,
              {:texture, texture_index},
              "Invalid image index: #{image_index}"
            )
          end

        _ ->
          context
      end

    case texture do
      %{sampler: sampler_index} when is_integer(sampler_index) ->
        if sampler_index >= 0 and sampler_index < length(samplers) do
          context
        else
          Context.add_error(
            context,
            {:texture, texture_index},
            "Invalid sampler index: #{sampler_index}"
          )
        end

      _ ->
        context
    end
  end

  defp validate_accessor_references(context, accessor, accessor_index, document) do
    buffer_views = document.buffer_views || []

    case accessor do
      %{buffer_view: buffer_view_index} when is_integer(buffer_view_index) ->
        if buffer_view_index >= 0 and buffer_view_index < length(buffer_views) do
          context
        else
          # Check if buffer_view_indices validation should be overridden
          if Context.has_override?(context, :buffer_view_indices) do
            Context.add_warning(
              context,
              {:accessor, accessor_index},
              "Invalid bufferView index: #{buffer_view_index} (validation overridden)"
            )
          else
            Context.add_error(
              context,
              {:accessor, accessor_index},
              "Invalid bufferView index: #{buffer_view_index}"
            )
          end
        end

      _ ->
        # Check if accessor_buffer_views validation should be overridden
        if Context.has_override?(context, :accessor_buffer_views) do
          context
        else
          context
        end
    end
  end

  defp validate_buffer_view_references(context, buffer_view, buffer_view_index, document) do
    buffers = document.buffers || []

    case buffer_view do
      %{buffer: buffer_index} when is_integer(buffer_index) ->
        if buffer_index >= 0 and buffer_index < length(buffers) do
          context
        else
          Context.add_error(
            context,
            {:buffer_view, buffer_view_index},
            "Invalid buffer index: #{buffer_index}"
          )
        end

      _ ->
        Context.add_error(
          context,
          {:buffer_view, buffer_view_index},
          "Buffer index is required for bufferView"
        )
    end
  end

  defp validate_buffer_references(context, _buffer, _buffer_index) do
    # Buffers don't have index references, but we could validate URI format here
    context
  end

  # Extension validation
  defp validate_extensions(%Context{document: document} = context) do
    ExtensionRouter.validate(context, document)
  end

  # Schema validation
  defp validate_schema(%Context{} = context) do
    SchemaValidator.validate(context)
  end

  # Array validation
  defp validate_arrays(%Context{document: document} = context) do
    context
    |> validate_array_bounds(:scenes, document.scenes)
    |> validate_array_bounds(:nodes, document.nodes)
    |> validate_array_bounds(:meshes, document.meshes)
    |> validate_array_bounds(:materials, document.materials)
    |> validate_array_bounds(:textures, document.textures)
    |> validate_array_bounds(:images, document.images)
    |> validate_array_bounds(:samplers, document.samplers)
    |> validate_array_bounds(:accessors, document.accessors)
    |> validate_array_bounds(:buffer_views, document.buffer_views)
    |> validate_array_bounds(:buffers, document.buffers)
    |> validate_array_bounds(:cameras, document.cameras)
    |> validate_array_bounds(:skins, document.skins)
    |> validate_array_bounds(:animations, document.animations)
  end

  defp validate_array_bounds(context, _field, nil), do: context
  defp validate_array_bounds(context, _field, []), do: context

  defp validate_array_bounds(context, field, array) when is_list(array) do
    if length(array) > 0 do
      context
    else
      Context.add_warning(context, field, "Empty array - consider omitting field")
    end
  end

  defp validate_array_bounds(context, field, _),
    do: Context.add_error(context, field, "Must be an array")

  # Required fields validation
  defp validate_required_fields(%Context{document: document} = context) do
    if is_nil(document.asset) do
      Context.add_error(context, :asset, "Asset field is required")
    else
      context
    end
  end



  # Finalize validation and return result
  defp finalize_validation(%Context{mode: mode} = context) do
    case {mode, Context.has_errors?(context)} do
      {:strict, true} -> {:error, Context.to_report(context)}
      {:strict, false} -> {:ok, context.document}
      {:permissive, _} -> handle_permissive_result(context)
      {:warning_only, _} -> {:ok, context.document}
    end
  end

  defp handle_permissive_result(%Context{} = context) do
    if Context.has_critical_errors?(context) do
      {:error, Context.to_report(context)}
    else
      {:ok, context.document}
    end
  end
end
