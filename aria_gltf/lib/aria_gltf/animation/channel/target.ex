# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Animation.Channel.Target do
  @moduledoc """
  The target of an animation channel.

  This module represents the target of a glTF animation channel as defined in the glTF 2.0 specification.
  A target specifies which node and which property of that node should be animated.
  """

  @type path_t :: :translation | :rotation | :scale | :weights

  @type t :: %__MODULE__{
          node: non_neg_integer() | nil,
          path: path_t(),
          extensions: map() | nil,
          extras: any() | nil
        }

  @enforce_keys [:path]
  defstruct [
    :node,
    :path,
    :extensions,
    :extras
  ]

  @valid_paths [:translation, :rotation, :scale, :weights]

  @doc """
  Creates a new animation target with the required path and optional node.
  """
  @spec new(path_t(), non_neg_integer() | nil) :: t()
  def new(path, node \\ nil) when path in @valid_paths do
    %__MODULE__{
      path: path,
      node: node
    }
  end

  @doc """
  Parses an animation target from JSON data.
  """
  @spec from_json(map()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_map(json) do
    with {:ok, path} <- parse_path(json),
         {:ok, node} <- parse_node(json) do
      target = %__MODULE__{
        path: path,
        node: node,
        extensions: Map.get(json, "extensions"),
        extras: Map.get(json, "extras")
      }

      {:ok, target}
    end
  end

  defp parse_path(%{"path" => path_string}) when is_binary(path_string) do
    case path_string do
      "translation" -> {:ok, :translation}
      "rotation" -> {:ok, :rotation}
      "scale" -> {:ok, :scale}
      "weights" -> {:ok, :weights}
      _ -> {:error, :invalid_path}
    end
  end

  defp parse_path(_), do: {:error, :missing_path}

  defp parse_node(%{"node" => node}) when is_integer(node) and node >= 0 do
    {:ok, node}
  end

  defp parse_node(_json) when is_map(_json), do: {:ok, nil}

  @doc """
  Converts the animation target to JSON format.
  """
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = target) do
    json = %{
      "path" => path_to_string(target.path)
    }

    json
    |> put_if_present("node", target.node)
    |> put_if_present("extensions", target.extensions)
    |> put_if_present("extras", target.extras)
  end

  defp path_to_string(:translation), do: "translation"
  defp path_to_string(:rotation), do: "rotation"
  defp path_to_string(:scale), do: "scale"
  defp path_to_string(:weights), do: "weights"

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Gets the node index for this target.
  """
  @spec node_index(t()) :: non_neg_integer() | nil
  def node_index(%__MODULE__{node: node}), do: node

  @doc """
  Gets the animation path for this target.
  """
  @spec path(t()) :: path_t()
  def path(%__MODULE__{path: path}), do: path

  @doc """
  Validates the animation target structure.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE___{path: path, node: node}) do
    with :ok <- validate_path(path),
         :ok <- validate_node(node) do
    end
  end

  defp validate_path(path) when path in @valid_paths, do: :ok
  defp validate_path(_), do: {:error, :invalid_path}

  defp validate_node(nil), do: :ok
  defp validate_node(node) when is_integer(node) and node >= 0, do: :ok
  defp validate_node(_), do: {:error, :invalid_node_index}

  @doc """
  Returns the list of valid animation paths.
  """
  @spec valid_paths() :: [path_t()]
  def valid_paths, do: @valid_paths
end
