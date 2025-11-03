# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.SchemaValidator do
  @moduledoc """
  JSON schema validation for glTF 2.0 documents.

  This module validates glTF documents against the official glTF 2.0 JSON schema
  to ensure structural compliance with the specification.
  """

  alias AriaGltf.Document
  alias AriaGltf.Validation.{Context}

  @doc """
  Validates a document against the glTF 2.0 JSON schema.
  """
  @spec validate(Context.t()) :: Context.t()
  def validate(%Context{document: document} = context) do
    # Convert document to JSON for schema validation
    json = Document.to_json(document)

    # Validate against schema
    case validate_json_schema(json) do
      :ok -> context
      {:error, errors} -> add_schema_errors(context, errors)
    end
  end

  # Schema validation implementation
  defp validate_json_schema(json) when is_map(json) do
    # Comprehensive structural validation following glTF 2.0 specification
    errors = []

    # Check required top-level fields
    errors = check_required_field(errors, json, "asset", "Root asset field is required")

    # Check asset structure
    errors =
      if asset = json["asset"] do
        errors
        |> check_required_field(asset, "version", "Asset version is required")
        |> check_field_type(asset, "version", "string", "Asset version must be a string")
        |> validate_asset_version(asset)
        |> check_field_type(asset, "generator", "string", "Asset generator must be a string")
        |> check_field_type(asset, "copyright", "string", "Asset copyright must be a string")
      else
        errors
      end

    # Check array fields are actually arrays
    array_fields = [
      "scenes",
      "nodes",
      "meshes",
      "materials",
      "textures",
      "images",
      "samplers",
      "accessors",
      "bufferViews",
      "buffers",
      "cameras",
      "skins",
      "animations"
    ]

    errors =
      Enum.reduce(array_fields, errors, fn field, acc ->
        if _value = json[field] do
          check_field_type(acc, json, field, "array", "#{field} must be an array")
        else
          acc
        end
      end)

    # Check scene index is valid
    errors =
      if scene_index = json["scene"] do
        scenes = json["scenes"] || []

        if not is_integer(scene_index) or scene_index < 0 or scene_index >= length(scenes) do
          ["Invalid scene index: #{scene_index}" | errors]
        else
          errors
        end
      else
        errors
      end

    # Validate extension fields
    errors =
      errors
      |> check_field_type(json, "extensionsUsed", "array", "extensionsUsed must be an array")
      |> check_field_type(
        json,
        "extensionsRequired",
        "array",
        "extensionsRequired must be an array"
      )

    # Validate numeric constraints
    errors = validate_numeric_constraints(errors, json)

    case errors do
      [] -> :ok
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp validate_asset_version(errors, asset) do
    case Map.get(asset, "version") do
      "2.0" ->
        errors

      version when is_binary(version) ->
        ["Unsupported glTF version: #{version}. Only 2.0 is supported" | errors]

      # Already handled by type check
      _ ->
        errors
    end
  end

  defp validate_numeric_constraints(errors, json) do
    # Validate that numeric fields are within acceptable ranges
    errors =
      if scenes = json["scenes"] do
        validate_scenes_structure(errors, scenes)
      else
        errors
      end

    errors =
      if nodes = json["nodes"] do
        validate_nodes_structure(errors, nodes)
      else
        errors
      end

    errors =
      if accessors = json["accessors"] do
        validate_accessors_structure(errors, accessors)
      else
        errors
      end

    errors
  end

  defp validate_scenes_structure(errors, scenes) when is_list(scenes) do
    Enum.with_index(scenes)
    |> Enum.reduce(errors, fn {scene, index}, acc ->
      case scene do
        %{"nodes" => nodes} when is_list(nodes) ->
          # Check that all node indices are non-negative integers
          invalid_nodes =
            Enum.filter(nodes, fn node_idx ->
              not is_integer(node_idx) or node_idx < 0
            end)

          if length(invalid_nodes) > 0 do
            ["Scene #{index} contains invalid node indices: #{inspect(invalid_nodes)}" | acc]
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  defp validate_scenes_structure(errors, _), do: errors

  defp validate_nodes_structure(errors, nodes) when is_list(nodes) do
    Enum.with_index(nodes)
    |> Enum.reduce(errors, fn {node, index}, acc ->
      acc
      |> validate_node_transform(node, index)
      |> validate_node_references(node, index)
    end)
  end

  defp validate_nodes_structure(errors, _), do: errors

  defp validate_node_transform(errors, node, index) do
    errors =
      if translation = Map.get(node, "translation") do
        if is_list(translation) and length(translation) == 3 and
             Enum.all?(translation, &is_number/1) do
          errors
        else
          ["Node #{index} translation must be array of 3 numbers" | errors]
        end
      else
        errors
      end

    errors =
      if rotation = Map.get(node, "rotation") do
        if is_list(rotation) and length(rotation) == 4 and Enum.all?(rotation, &is_number/1) do
          errors
        else
          ["Node #{index} rotation must be array of 4 numbers (quaternion)" | errors]
        end
      else
        errors
      end

    errors =
      if scale = Map.get(node, "scale") do
        if is_list(scale) and length(scale) == 3 and Enum.all?(scale, &is_number/1) do
          errors
        else
          ["Node #{index} scale must be array of 3 numbers" | errors]
        end
      else
        errors
      end

    if matrix = Map.get(node, "matrix") do
      if is_list(matrix) and length(matrix) == 16 and Enum.all?(matrix, &is_number/1) do
        errors
      else
        ["Node #{index} matrix must be array of 16 numbers" | errors]
      end
    else
      errors
    end
  end

  defp validate_node_references(errors, node, index) do
    errors =
      if children = Map.get(node, "children") do
        if is_list(children) and
             Enum.all?(children, fn child -> is_integer(child) and child >= 0 end) do
          errors
        else
          ["Node #{index} children must be array of non-negative integers" | errors]
        end
      else
        errors
      end

    # Validate optional references
    ["mesh", "camera", "skin"]
    |> Enum.reduce(errors, fn field, acc ->
      case Map.get(node, field) do
        value when is_integer(value) and value >= 0 ->
          acc

        value when not is_nil(value) ->
          ["Node #{index} #{field} must be non-negative integer" | acc]

        _ ->
          acc
      end
    end)
  end

  defp validate_accessors_structure(errors, accessors) when is_list(accessors) do
    Enum.with_index(accessors)
    |> Enum.reduce(errors, fn {accessor, index}, acc ->
      validate_accessor_structure(acc, accessor, index)
    end)
  end

  defp validate_accessors_structure(errors, _), do: errors

  defp validate_accessor_structure(errors, accessor, index) do
    # Validate required fields
    errors =
      check_required_field(errors, accessor, "count", "Accessor #{index} count is required")

    errors = check_required_field(errors, accessor, "type", "Accessor #{index} type is required")

    # Validate count is positive integer
    errors =
      case Map.get(accessor, "count") do
        count when is_integer(count) and count > 0 ->
          errors

        count when not is_nil(count) ->
          ["Accessor #{index} count must be positive integer, got: #{inspect(count)}" | errors]

        _ ->
          errors
      end

    # Validate type enum
    errors =
      case Map.get(accessor, "type") do
        type when type in ["SCALAR", "VEC2", "VEC3", "VEC4", "MAT2", "MAT3", "MAT4"] ->
          errors

        type when not is_nil(type) ->
          ["Accessor #{index} type must be valid enum, got: #{type}" | errors]

        _ ->
          errors
      end

    # Validate componentType enum
    errors =
      case Map.get(accessor, "componentType") do
        ct when ct in [5120, 5121, 5122, 5123, 5125, 5126] ->
          errors

        ct when not is_nil(ct) ->
          ["Accessor #{index} componentType must be valid enum, got: #{ct}" | errors]

        _ ->
          errors
      end

    # Validate optional fields
    errors =
      if buffer_view = Map.get(accessor, "bufferView") do
        if is_integer(buffer_view) and buffer_view >= 0 do
          errors
        else
          ["Accessor #{index} bufferView must be non-negative integer" | errors]
        end
      else
        errors
      end

    if byte_offset = Map.get(accessor, "byteOffset") do
      if is_integer(byte_offset) and byte_offset >= 0 do
        errors
      else
        ["Accessor #{index} byteOffset must be non-negative integer" | errors]
      end
    else
      errors
    end
  end

  defp check_required_field(errors, map, field, message) do
    if Map.has_key?(map, field) do
      errors
    else
      [message | errors]
    end
  end

  defp check_field_type(errors, map, field, expected_type, message) do
    case {Map.get(map, field), expected_type} do
      {nil, _} -> errors
      {value, "string"} when is_binary(value) -> errors
      {value, "array"} when is_list(value) -> errors
      {value, "object"} when is_map(value) -> errors
      {value, "number"} when is_number(value) -> errors
      {value, "integer"} when is_integer(value) -> errors
      {value, "boolean"} when is_boolean(value) -> errors
      _ -> [message | errors]
    end
  end

  defp add_schema_errors(context, errors) do
    Enum.reduce(errors, context, fn error_msg, ctx ->
      Context.add_error(ctx, :schema, error_msg)
    end)
  end

  @doc """
  Validates specific glTF data types and constraints.
  """
  @spec validate_data_types(Context.t()) :: Context.t()
  def validate_data_types(%Context{} = context) do
    raise "TODO: Implement #{__MODULE__}.validate_data_types"
  end

  @doc """
  Validates glTF extension usage and requirements.
  """
  @spec validate_extensions(Context.t()) :: Context.t()
  def validate_extensions(%Context{document: document} = context) do
    used = document.extensions_used || []
    required = document.extensions_required || []

    # All required extensions must be in used extensions
    missing = required -- used

    Enum.reduce(missing, context, fn ext, ctx ->
      Context.add_error(
        ctx,
        :extensions,
        "Required extension '#{ext}' not declared in extensionsUsed"
      )
    end)
  end

  @doc """
  Validates accessor and buffer view relationships.
  """
  @spec validate_data_access(Context.t()) :: Context.t()
  def validate_data_access(%Context{document: document} = context) do
    accessors = document.accessors || []
    buffer_views = document.buffer_views || []
    buffers = document.buffers || []

    # Validate accessor -> buffer view -> buffer chain
    Enum.with_index(accessors)
    |> Enum.reduce(context, fn {accessor, index}, ctx ->
      validate_accessor_chain(ctx, accessor, index, buffer_views, buffers)
    end)
  end

  defp validate_accessor_chain(context, accessor, accessor_index, buffer_views, buffers) do
    case accessor do
      %{buffer_view: bv_index} when is_integer(bv_index) ->
        if bv_index >= 0 and bv_index < length(buffer_views) do
          buffer_view = Enum.at(buffer_views, bv_index)
          validate_buffer_view_chain(context, buffer_view, bv_index, buffers, accessor_index)
        else
          Context.add_error(
            context,
            {:accessor, accessor_index},
            "Invalid bufferView index: #{bv_index}"
          )
        end

      # No buffer view reference is valid for some accessors
      _ ->
        context
    end
  end

  defp validate_buffer_view_chain(context, buffer_view, bv_index, buffers, accessor_index) do
    case buffer_view do
      %{buffer: buffer_index} when is_integer(buffer_index) ->
        if buffer_index >= 0 and buffer_index < length(buffers) do
          context
        else
          Context.add_error(
            context,
            {:buffer_view, bv_index},
            "Invalid buffer index: #{buffer_index} (referenced by accessor #{accessor_index})"
          )
        end

      _ ->
        Context.add_error(
          context,
          {:buffer_view, bv_index},
          "Buffer index is required for bufferView"
        )
    end
  end
end
