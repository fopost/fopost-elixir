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
          # One response struct per API shape means one near-identical from_map/1 per
          # struct. That repetition is the point: a field list you can read beside the
          # API's own docs beats a macro that hides it.
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Design.TagTODO, []},
          {Credo.Check.Design.TagFIXME, []},
          # A pipeline starting from a literal map is how request bodies are built here.
          {Credo.Check.Refactor.PipeChainStart, []}
        ]
      }
    }
  ]
}
