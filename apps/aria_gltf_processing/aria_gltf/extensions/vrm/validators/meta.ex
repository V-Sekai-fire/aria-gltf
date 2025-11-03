# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Extensions.Vrm.Validators.Meta do
  @moduledoc """
  VRM meta information validation.

  Validates VRM meta fields including title, version, authors, copyright,
  contact information, reference, and thumbnail image.
  """

  alias AriaGltf.{Document, Validation.Context}

  @doc """
  Validates VRM meta information.
  """
  @spec validate(Context.t(), map(), Document.t()) :: Context.t()
  def validate(context, meta, document) when is_map(meta) do
    context
    |> validate_meta_title(meta)
    |> validate_meta_version(meta)
    |> validate_meta_authors(meta)
    |> validate_meta_copyright_information(meta)
    |> validate_meta_contact_information(meta)
    |> validate_meta_reference(meta)
    |> validate_meta_thumbnail_image(meta, document)
  end

  def validate(context, _, _), do: context

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
end

