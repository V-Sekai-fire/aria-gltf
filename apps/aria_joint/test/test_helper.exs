# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

# Load fixtures
Code.require_file("fixtures/joint_fixtures.exs", __DIR__)

# Start the AriaJoint application to ensure the registry is available
{:ok, _} = Application.ensure_all_started(:aria_joint)

ExUnit.start()
