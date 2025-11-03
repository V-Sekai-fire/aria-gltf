# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf.Validation.SchemaCache do
  @moduledoc """
  In-memory cache for JSON schemas.

  Provides a simple cache mechanism for schema files to avoid repeated
  file I/O during validation.
  """

  use Agent

  @doc """
  Starts the schema cache agent.

  This is typically called during application startup.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    Agent.start_link(fn -> %{} end, opts)
  end

  @doc """
  Gets a schema from the cache.

  ## Parameters

  - `schema_name`: Name of the schema to retrieve

  ## Returns

  Schema map if cached, `nil` otherwise
  """
  @spec get(String.t()) :: map() | nil
  def get(schema_name) when is_binary(schema_name) do
    case ensure_started() do
      {:ok, pid} ->
        Agent.get(pid, fn cache -> Map.get(cache, schema_name) end)

      {:error, _} ->
        nil
    end
  end

  @doc """
  Puts a schema into the cache.

  ## Parameters

  - `schema_name`: Name of the schema
  - `schema`: Schema map to cache

  ## Returns

  `:ok`
  """
  @spec put(String.t(), map()) :: :ok
  def put(schema_name, schema) when is_binary(schema_name) and is_map(schema) do
    case ensure_started() do
      {:ok, pid} ->
        Agent.update(pid, fn cache -> Map.put(cache, schema_name, schema) end)

      {:error, _} ->
        # If agent not started, use process dictionary as fallback
        :persistent_term.put({__MODULE__, schema_name}, schema)
        :ok
    end
  end

  @doc """
  Clears the schema cache.
  """
  @spec clear() :: :ok
  def clear do
    case ensure_started() do
      {:ok, pid} ->
        Agent.update(pid, fn _cache -> %{} end)

      {:error, _} ->
        # Clear persistent term entries
        :persistent_term.erase()
        :ok
    end
  end

  # Ensure cache agent is started
  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        # Try to start the agent
        case start_link(name: __MODULE__) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          error -> error
        end

      pid ->
        {:ok, pid}
    end
  end
end

