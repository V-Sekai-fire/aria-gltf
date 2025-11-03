# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "apps/aria_gltf_processing/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/test/"]
      },
      checks: [
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 15},
        {Credo.Check.Warning.UnusedFunctionReturnValue, ignore: ~r/^test_/},
        {Credo.Check.Design.TagTODO, exit_status: 0},
        {Credo.Check.Design.TagFIXME, exit_status: 0}
      ]
    }
  ]
}

