# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.Registry do
  @moduledoc """
  Registry management for Joint nodes.

  Handles node registration, updates, and lookup operations with proper
  error handling and timeout management.
  """

  @registry_name :joint_registry

  @type node_id() :: reference()
  @type joint_id() :: term()
  @type joint_error ::
          :registry_unavailable
          | :node_not_found
          | :registry_timeout
          | :registry_sync_failed

  @doc """
  Updates an existing joint in the registry.
  """
  def update_joint(joint) do
    case Registry.lookup(:joint_registry, joint.id) do
      [{_pid, _}] ->
        Registry.update_value(:joint_registry, joint.id, fn _old -> joint end)
        {:ok, joint}

      [] ->
        {:error, :joint_not_found}
    end
  end

  @doc """
  Remove a joint from the registry.
  """
  def remove_joint(joint_id) do
    case Registry.unregister(:joint_registry, joint_id) do
      :ok -> :ok
    end
  end

  @doc """
  Gets metadata for a specific joint.

  ## Parameters

  - `joint_id`: ID of the joint to get metadata for

  ## Returns

  Joint metadata map, or `nil` if not found.
  """
  def get_joint_metadata(joint_id) do
    case Registry.lookup(:joint_registry, joint_id) do
      [{_pid, joint}] -> joint.metadata
      [] -> nil
    end
  end

  @doc """
  Looks up a joint by ID from the registry.

  ## Parameters

  - `registry_name`: Name of the registry (usually :joint_registry)
  - `joint_id`: ID of the joint to look up

  ## Returns

  `[{pid, joint}]` if found, `[]` if not found.
  """
  def lookup(registry_name, joint_id) when registry_name == :joint_registry do
    Registry.lookup(registry_name, joint_id)
  end

  @doc """
  Updates a value in the registry.

  ## Parameters

  - `registry_name`: Name of the registry (usually :joint_registry)
  - `joint_id`: ID of the joint to update
  - `update_fn`: Function to apply to the current value

  ## Returns

  `{:ok, new_value}` on success, `{:error, reason}` on failure.
  """
  def update_value(registry_name, joint_id, update_fn) when registry_name == :joint_registry do
    case Registry.lookup(registry_name, joint_id) do
      [{_pid, _old_joint}] ->
        case Registry.update_value(registry_name, joint_id, update_fn) do
          {new_value, _old_value} -> {:ok, new_value}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Ensures the joint registry exists and is available.

  ## Returns

  `:ok` if registry is available, `{:error, reason}` if not.
  """
  def ensure_registry() do
    case Registry.start_link(keys: :unique, name: :joint_registry) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Look up a node by ID.
  """
  @spec get_node_by_id(node_id()) :: AriaJoint.Joint.t() | nil
  def get_node_by_id(node_id) do
    case Registry.lookup(@registry_name, node_id) do
      [{_pid, node}] -> node
      [] -> nil
    end
  end

  @doc """
  Register a node in the registry.
  """
  @spec register_node(AriaJoint.Joint.t()) :: {:ok, pid()} | {:error, joint_error()}
  def register_node(node) do
    ensure_registry()

    case Registry.register(@registry_name, node.id, node) do
      {:ok, _pid} -> {:ok, self()}
      {:error, {:already_registered, _pid}} -> {:error, :already_registered}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Update a node in the registry.
  """
  @spec update_node(AriaJoint.Joint.t()) :: :ok | {:error, joint_error()}
  def update_node(node) do
    try do
      case Registry.lookup(@registry_name, node.id) do
        [{_pid, _old_node}] ->
          case Registry.update_value(@registry_name, node.id, fn _old_node -> node end) do
            {_new_value, _old_value} -> :ok
          end

        [] ->
          {:error, :node_not_found}
      end
    rescue
      _error -> {:error, :registry_unavailable}
    end
  end

  @doc """
  Unregister a node from the registry.
  """
  @spec unregister_node(node_id()) :: :ok
  def unregister_node(node_id) do
    Registry.unregister(@registry_name, node_id)
  end

  @doc """
  Check if registry is available with timeout.
  """
  @spec ensure_registry_with_timeout() :: {:ok, pid()} | {:error, joint_error()}
  def ensure_registry_with_timeout do
    try do
      case Process.whereis(@registry_name) do
        nil -> {:error, :registry_unavailable}
        pid when is_pid(pid) -> {:ok, pid}
      end
    rescue
      _error -> {:error, :registry_unavailable}
    end
  end
end
