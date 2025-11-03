# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaJoint.DirtyState do
  @moduledoc """
  Dirty state flag management for Joint nodes.

  Handles efficient tracking of what needs recomputation through
  dirty flags for transforms and hierarchy changes.
  """

  import Bitwise

  @type dirty_state() ::
          :dirty_none
          | :dirty_vectors
          | :dirty_local
          | :dirty_global
          | [:dirty_vectors | :dirty_local | :dirty_global]

  # Dirty state constants
  @dirty_none :dirty_none
  @dirty_vectors :dirty_vectors
  @dirty_local :dirty_local
  @dirty_global :dirty_global

  @doc """
  Add a dirty flag to current dirty state.
  """
  @spec add_dirty_flag(dirty_state(), atom()) :: dirty_state()
  def add_dirty_flag(@dirty_none, flag), do: flag

  def add_dirty_flag(current_flags, flag) when is_list(current_flags) do
    if flag in current_flags do
      current_flags
    else
      [flag | current_flags]
    end
  end

  def add_dirty_flag(current_flag, flag) when is_atom(current_flag) do
    if current_flag == flag do
      current_flag
    else
      [flag, current_flag]
    end
  end

  @doc """
  Remove a dirty flag from current dirty state.
  """
  @spec remove_dirty_flag(dirty_state(), atom()) :: dirty_state()
  def remove_dirty_flag(@dirty_none, _flag), do: @dirty_none

  def remove_dirty_flag(current_flags, flag) when is_list(current_flags) do
    remaining = List.delete(current_flags, flag)

    case remaining do
      [] -> @dirty_none
      [single_flag] -> single_flag
      multiple -> multiple
    end
  end

  def remove_dirty_flag(current_flag, flag) when is_atom(current_flag) do
    if current_flag == flag do
      @dirty_none
    else
      current_flag
    end
  end

  @doc """
  Check if dirty state has a specific flag.
  """
  @spec has_dirty_flag?(dirty_state(), atom()) :: boolean()
  def has_dirty_flag?(@dirty_none, _flag), do: false

  def has_dirty_flag?(current_flags, flag) when is_list(current_flags) do
    flag in current_flags
  end

  def has_dirty_flag?(current_flag, flag) when is_atom(current_flag) do
    current_flag == flag
  end

  @doc """
  Get the dirty_none constant.
  """
  @spec dirty_none() :: atom()
  def dirty_none, do: @dirty_none

  @doc """
  Get the dirty_vectors constant.
  """
  @spec dirty_vectors() :: atom()
  def dirty_vectors, do: @dirty_vectors

  @doc """
  Get the dirty_local constant.
  """
  @spec dirty_local() :: atom()
  def dirty_local, do: @dirty_local

  @doc """
  Get the dirty_global constant.
  """
  @spec dirty_global() :: atom()
  def dirty_global, do: @dirty_global

  @doc """
  Convert dirty state to integer representation for tensor operations.

  ## Examples

      iex> AriaJoint.DirtyState.to_integer(:dirty_none)
      0

      iex> AriaJoint.DirtyState.to_integer(:dirty_vectors)
      1

      iex> AriaJoint.DirtyState.to_integer([:dirty_vectors, :dirty_local])
      3
  """
  @spec to_integer(dirty_state()) :: integer()
  def to_integer(@dirty_none), do: 0
  def to_integer(@dirty_vectors), do: 1
  def to_integer(@dirty_local), do: 2
  def to_integer(@dirty_global), do: 4

  def to_integer(flags) when is_list(flags) do
    Enum.reduce(flags, 0, fn flag, acc ->
      acc + to_integer(flag)
    end)
  end

  @doc """
  Convert integer representation back to dirty state for tensor operations.

  ## Examples

      iex> AriaJoint.DirtyState.from_integer(0)
      :dirty_none

      iex> AriaJoint.DirtyState.from_integer(1)
      :dirty_vectors

      iex> AriaJoint.DirtyState.from_integer(3)
      [:dirty_vectors, :dirty_local]
  """
  @spec from_integer(integer()) :: dirty_state()
  def from_integer(0), do: @dirty_none
  def from_integer(1), do: @dirty_vectors
  def from_integer(2), do: @dirty_local
  def from_integer(4), do: @dirty_global

  def from_integer(int) when is_integer(int) and int > 0 do
    flags = []
    flags = if (int &&& 4) != 0, do: [@dirty_global | flags], else: flags
    flags = if (int &&& 2) != 0, do: [@dirty_local | flags], else: flags
    flags = if (int &&& 1) != 0, do: [@dirty_vectors | flags], else: flags

    case flags do
      [] -> @dirty_none
      [single] -> single
      multiple -> multiple
    end
  end

  def from_integer(_), do: @dirty_none
end
