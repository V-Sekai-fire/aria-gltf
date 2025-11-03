# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Animation.Channel do
  @moduledoc """
  An animation channel combines an animation sampler with a target property being animated.

  This module represents a glTF animation channel as defined in the glTF 2.0 specification.
  A channel connects a sampler (which defines the keyframe data) to a specific property
  of a specific node (the target).
  """

  alias AriaGltf.Animation.Channel.Target

  @type t :: %__MODULE__{
          sampler: non_neg_integer(),
          target: Target.t(),
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:sampler, :target]
  defstruct [
    :sampler,
    :target,
    :extensions,
    :extras
  ]

  @doc """
  Creates a new animation channel with the required sampler index and target.
  """
  @spec new(non_neg_integer(), Target.t()) :: t()
  def new(sampler_index, %Target{} = target)
      when is_integer(sampler_index) and sampler_index >= 0 do
    %__MODULE__{
      sampler: sampler_index,
      target: target
    }
  end

  @doc """
  Parses an animation channel from JSON data.
  """
  @spec from_json(map()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_map(json) do
    with {:ok, sampler} <- parse_sampler(json),
         {:ok, target} <- parse_target(json) do
      channel = %__MODULE__{
        sampler: sampler,
        target: target,
        extensions: Map.get(json, "extensions"),
        extras: Map.get(json, "extras")
      }

      {:ok, channel}
    end
  end

  defp parse_sampler(%{"sampler" => sampler}) when is_integer(sampler) and sampler >= 0 do
    {:ok, sampler}
  end

  defp parse_sampler(_), do: {:error, :missing_or_invalid_sampler}

  defp parse_target(%{"target" => target_json}) when is_map(target_json) do
    Target.from_json(target_json)
  end

  defp parse_target(_), do: {:error, :missing_target}

  @doc """
  Converts the animation channel to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = channel) do
    json = %{
      "sampler" => channel.sampler,
      "target" => Target.to_json(channel.target)
    }

    json
    |> put_if_present("extensions", channel.extensions)
    |> put_if_present("extras", channel.extras)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Gets the sampler index for this channel.
  """
  @spec sampler_index(t()) :: non_neg_integer()
  def sampler_index(%__MODULE__{sampler: sampler}), do: sampler

  @doc """
  Gets the target for this channel.
  """
  @spec target(t()) :: Target.t()
  def target(%__MODULE__{target: target}), do: target

  @doc """
  Validates the animation channel structure.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{sampler: sampler, target: target}) do
    with :ok <- validate_sampler_index(sampler),
         :ok <- Target.validate(target) do
      :ok
    end
  end

  defp validate_sampler_index(sampler) when is_integer(sampler) and sampler >= 0, do: :ok
  defp validate_sampler_index(_), do: {:error, :invalid_sampler_index}
end
