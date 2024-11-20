defmodule Markbug.MixProject do
  use Mix.Project

  @version "0.9.0"

  @description "Fast Elixir Markdown Parser"
  @repo_url "https://github.com/cthuflu/markbug"

  def project do
    [
      app: :markbug,
      version: @version,
      elixir: "~> 1.17",
      deps: deps(),

      # Hex
      package: hex_package(),
      description: @description,

      # Docs
      name: "markbug",
      docs: [
        source_ref: "v#{@version}",
        source_url: @repo_url,
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def hex_package do
    [
      maintainers: ["Cthuflu"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @repo_url
      },
      files: ~w(lib mix.exs *.md)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
