defmodule FoPost.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/fopost/fopost-elixir"

  def project do
    [
      app: :fopost,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "FoPost",
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: "https://fopost.com",
      dialyzer: dialyzer()
    ]
  end

  def application do
    [extra_applications: [:crypto, :logger]]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Official Elixir SDK for the FoPost API: schedule, publish, and analyze social " <>
      "media content across every connected platform."
  end

  defp package do
    [
      maintainers: ["Porter Bridge, LLC"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Homepage" => "https://fopost.com",
        "Documentation" => "https://fopost.com/docs"
      },
      files: ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "FoPost",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Client: [FoPost, FoPost.Client, FoPost.Error, FoPost.Content, FoPost.Page],
        Resources: [
          FoPost.Accounts,
          FoPost.Analytics,
          FoPost.Automations,
          FoPost.Communities,
          FoPost.Labels,
          FoPost.Media,
          FoPost.Posts,
          FoPost.Webhooks,
          FoPost.Workspaces
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts"
    ]
  end
end
