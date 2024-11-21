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

  def application do
    [
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

  defp deps do
    [
    ]
  end
end
