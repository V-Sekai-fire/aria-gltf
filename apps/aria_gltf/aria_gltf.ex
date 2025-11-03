# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaGltf do
  @moduledoc """
  This module serves as the public API for the `aria_gltf` application.
  All external calls to `aria_gltf` functionality should go through this module.
  """

  # Public API functions will be delegated here.
  defdelegate new(asset), to: AriaGltf.Document
  defdelegate from_json(json), to: AriaGltf.Document
  defdelegate to_json(document), to: AriaGltf.Document
end
