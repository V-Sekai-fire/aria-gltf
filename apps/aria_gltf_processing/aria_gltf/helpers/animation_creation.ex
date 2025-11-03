# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Helpers.AnimationCreation do
  @moduledoc """
  Helper functions for creating glTF animations.

  This module provides utilities for creating animation structures with
  channels, samplers, and various interpolation methods.
  """

  alias AriaGltf.Animation

  @doc """
  Creates a simple animation with linear interpolation.

  ## Options

  - `:name` - Animation name
  - `:target_node` - Target node index
  - `:path` - Animation path ("translation", "rotation", "scale", "weights")
  - `:input_accessor` - Input (time) accessor index
  - `:output_accessor` - Output (values) accessor index
  - `:interpolation` - Interpolation method (default: "LINEAR")

  ## Examples

      iex> AriaGltf.Helpers.AnimationCreation.create_simple_animation(
      ...>   name: "Rotate Y",
      ...>   target_node: 0,
      ...>   path: "rotation",
      ...>   input_accessor: 0,
      ...>   output_accessor: 1
      ...> )
      %AriaGltf.Animation{
        name: "Rotate Y",
        channels: [
          %AriaGltf.Animation.Channel{
            sampler: 0,
            target: %AriaGltf.Animation.Channel.Target{
              node: 0,
              path: "rotation"
            }
          }
        ],
        samplers: [
          %AriaGltf.Animation.Sampler{
            input: 0,
            output: 1,
            interpolation: "LINEAR"
          }
        ]
      }
  """
  @spec create_simple_animation(keyword()) :: Animation.t()
  def create_simple_animation(opts \\ []) do
    name = Keyword.get(opts, :name)
    target_node = Keyword.get(opts, :target_node)
    path = Keyword.get(opts, :path)
    input_accessor = Keyword.get(opts, :input_accessor)
    output_accessor = Keyword.get(opts, :output_accessor)
    interpolation = Keyword.get(opts, :interpolation, "LINEAR")

    target = %Animation.Channel.Target{
      node: target_node,
      path: path
    }

    channel = %Animation.Channel{
      sampler: 0,
      target: target
    }

    sampler = %Animation.Sampler{
      input: input_accessor,
      output: output_accessor,
      interpolation: interpolation
    }

    %Animation{
      name: name,
      channels: [channel],
      samplers: [sampler]
    }
  end
end
