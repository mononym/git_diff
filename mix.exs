defmodule GitDiff.Mixfile do
  use Mix.Project

  def project do
    [
      app: :git_diff,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      elixir: "~> 1.5",
      name: "GitDiff",
      package: package(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      source_url: "https://github.com/mononym/git_diff",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      version: "0.6.2"
    ]
  end

  defp description() do
    "A simple parser for output from 'git diff'"
  end

  defp package do
    [
      files: ["lib", "bench", "mix.exs", "README.md", "LICENSE.txt"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mononym/git_diff"},
      maintainers: ["Chris Hicks"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchfella, "~> 0.3.5", only: :dev},
      {:excoveralls, "~> 0.12.0", only: :test},
      {:ex_doc, "~> 0.21.2", only: :dev, runtime: false}
    ]
  end
end
