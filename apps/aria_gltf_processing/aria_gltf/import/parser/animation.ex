# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Import.Parser.Animation do
  @moduledoc """
  Animation-related parsing for glTF content.

  This module handles parsing of animations, channels, samplers, and skins from glTF JSON data.
  """

  alias AriaGltf.{Animation, Skin}

  @doc """
  Parses skins array from glTF JSON data.

  ## Examples

      iex> skins_data = [%{"joints" => [0, 1, 2], "inverseBindMatrices" => 0}]
      iex> AriaGltf.Import.Parser.Animation.parse_skins(skins_data)
      [%AriaGltf.Skin{joints: [0, 1, 2], inverse_bind_matrices: 0}]
  """
  @spec parse_skins(list() | nil) :: [Skin.t()]
  def parse_skins(nil), do: []

  def parse_skins(skins_data) when is_list(skins_data) do
    Enum.map(skins_data, &parse_skin/1)
  end

  @spec parse_skin(map()) :: Skin.t()
  defp parse_skin(skin_data) when is_map(skin_data) do
    %Skin{
      name: skin_data["name"],
      inverse_bind_matrices: skin_data["inverseBindMatrices"],
      skeleton: skin_data["skeleton"],
      joints: skin_data["joints"] || [],
      extensions: skin_data["extensions"],
      extras: skin_data["extras"]
    }
  end

  @doc """
  Parses animations array from glTF JSON data.

  ## Examples

      iex> animations_data = [%{"name" => "Animation", "channels" => [], "samplers" => []}]
      iex> AriaGltf.Import.Parser.Animation.parse_animations(animations_data)
      [%AriaGltf.Animation{name: "Animation", channels: [], samplers: []}]
  """
  @spec parse_animations(list() | nil) :: [Animation.t()]
  def parse_animations(nil), do: []

  def parse_animations(animations_data) when is_list(animations_data) do
    Enum.map(animations_data, &parse_animation/1)
  end

  @spec parse_animation(map()) :: Animation.t()
  defp parse_animation(animation_data) when is_map(animation_data) do
    %Animation{
      name: animation_data["name"],
      channels: parse_animation_channels(animation_data["channels"]),
      samplers: parse_animation_samplers(animation_data["samplers"]),
      extensions: animation_data["extensions"],
      extras: animation_data["extras"]
    }
  end

  @spec parse_animation_channels(list() | nil) :: [Animation.Channel.t()]
  defp parse_animation_channels(nil), do: []

  defp parse_animation_channels(channels_data) when is_list(channels_data) do
    Enum.map(channels_data, &parse_animation_channel/1)
  end

  @spec parse_animation_channel(map()) :: Animation.Channel.t()
  defp parse_animation_channel(channel_data) when is_map(channel_data) do
    %Animation.Channel{
      sampler: channel_data["sampler"],
      target: parse_animation_target(channel_data["target"]),
      extensions: channel_data["extensions"],
      extras: channel_data["extras"]
    }
  end

  @spec parse_animation_target(map() | nil) :: Animation.Channel.Target.t() | nil
  defp parse_animation_target(nil), do: nil

  defp parse_animation_target(target_data) when is_map(target_data) do
    %Animation.Channel.Target{
      node: target_data["node"],
      path: target_data["path"],
      extensions: target_data["extensions"],
      extras: target_data["extras"]
    }
  end

  @spec parse_animation_samplers(list() | nil) :: [Animation.Sampler.t()]
  defp parse_animation_samplers(nil), do: []

  defp parse_animation_samplers(samplers_data) when is_list(samplers_data) do
    Enum.map(samplers_data, &parse_animation_sampler/1)
  end

  @spec parse_animation_sampler(map()) :: Animation.Sampler.t()
  defp parse_animation_sampler(sampler_data) when is_map(sampler_data) do
    %Animation.Sampler{
      input: sampler_data["input"],
      interpolation: sampler_data["interpolation"] || "LINEAR",
      output: sampler_data["output"],
      extensions: sampler_data["extensions"],
      extras: sampler_data["extras"]
    }
  end
end
