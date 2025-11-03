# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.ExtensionRouter do
  @moduledoc """
  Extension validation routing for glTF 2.0 documents.

  This module validates extension usage and requirements, routes to specific
  extension validators, and checks for known extensions.
  """

  alias AriaGltf.Validation.Context

  @doc """
  Validates extensions in the document.

  Checks that all required extensions are in extensionsUsed, validates known
  extensions, and routes to specific extension validators.
  """
  @spec validate(Context.t(), AriaGltf.Document.t()) :: Context.t()
  def validate(context, document) do
    used_extensions = document.extensions_used || []
    required_extensions = document.extensions_required || []

    # Check that all required extensions are in used extensions
    missing_required = required_extensions -- used_extensions

    context =
      Enum.reduce(missing_required, context, fn ext, ctx ->
        Context.add_error(
          ctx,
          :extensions,
          "Required extension '#{ext}' not listed in extensionsUsed"
        )
      end)

    # Validate known extensions
    validate_known_extensions(context, used_extensions)
  end

  defp validate_known_extensions(context, extensions) do
    # List of known glTF extensions
    known_extensions = [
      "KHR_draco_mesh_compression",
      "KHR_lights_punctual",
      "KHR_materials_clearcoat",
      "KHR_materials_ior",
      "KHR_materials_transmission",
      "KHR_materials_unlit",
      "KHR_mesh_quantization",
      "KHR_texture_transform",
      "EXT_mesh_gpu_instancing",
      "EXT_texture_webp",
      "VRMC_vrm" # VRM 1.0 extension
    ]

    context =
      Enum.reduce(extensions, context, fn ext, ctx ->
        if ext in known_extensions or String.starts_with?(ext, ["KHR_", "EXT_", "VRMC_"]) do
          ctx
        else
          Context.add_warning(ctx, :extensions, "Unknown extension: #{ext}")
        end
      end)

    # Validate VRM extension if present
    if "VRMC_vrm" in extensions do
      validate_vrm_extension(context)
    else
      context
    end
  end

  # Validate VRM 1.0 extension
  defp validate_vrm_extension(context) do
    case Code.ensure_loaded(AriaGltf.Extensions.Vrm.Validator) do
      {:module, AriaGltf.Extensions.Vrm.Validator} ->
        AriaGltf.Extensions.Vrm.Validator.validate(context)

      {:error, _reason} ->
        # VRM validator not available, skip validation
        context
    end
  end
end

