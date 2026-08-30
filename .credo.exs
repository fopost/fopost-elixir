%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "mix.exs"],
        excluded: []
      },
      strict: true,
      color: true,
      checks: %{
        disabled: [
          # Every SDK module reaches for FoPost.Model / FoPost.Client helpers by their
          # full name in a handful of places; aliasing each one adds noise, not clarity.
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Design.TagTODO, []},
          {Credo.Check.Design.TagFIXME, []}
        ]
      }
    }
  ]
}
