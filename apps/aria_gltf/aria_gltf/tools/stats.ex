# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Tools.Stats do
  @moduledoc """
  Statistics and analysis tools for glTF documents.
  """

  alias AriaGltf.Document

  @doc """
  Generates statistics for a glTF document.
  
  Returns a map with counts and sizes for various document elements.
  """
  @spec get_stats(Document.t()) :: map()
  def get_stats(%Document{} = document) do
    %{
      meshes: length(document.meshes || []),
      nodes: length(document.nodes || []),
      materials: length(document.materials || []),
      textures: length(document.textures || []),
      animations: length(document.animations || []),
      scenes: length(document.scenes || []),
      buffers: length(document.buffers || []),
      buffer_size: calculate_buffer_size(document.buffers || []),
      images: length(document.images || []),
      image_size: calculate_image_size(document.images || []),
      cameras: length(document.cameras || []),
      skins: length(document.skins || [])
    }
  end

  defp calculate_buffer_size(buffers) do
    buffers
    |> Enum.map(fn buffer ->
      case buffer.data do
        data when is_binary(data) -> byte_size(data)
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp calculate_image_size(images) do
    images
    |> Enum.map(fn image ->
      case image.data do
        data when is_binary(data) -> byte_size(data)
        _ -> 0
      end
    end)
    |> Enum.sum()
  end
end

