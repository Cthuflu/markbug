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
      elixirc_paths: elixirc_paths(Mix.env()),
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

  def application do
    [
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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

  defp deps do
    [
    ]
  end
end
