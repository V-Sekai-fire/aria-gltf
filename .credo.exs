# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "apps/aria_joint/lib/",
          "apps/aria_gltf_processing/lib/",
          "apps/aria_ewbik/lib/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/test/"]
      },
      checks: [
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 15},
        {Credo.Check.Design.TagTODO, exit_status: 0},
        {Credo.Check.Design.TagFIXME, exit_status: 0}
      ]
    }
  ]
}

