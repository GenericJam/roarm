defmodule Roarm.MixProject do
  use Mix.Project

  def project do
    [
      app: :roarm,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Documentation
      name: "RoArm Elixir",
      description: "Elixir library for controlling Waveshare RoArm robot arms",
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Roarm.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_uart, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description: "Elixir library for controlling Waveshare RoArm robot arms via serial communication",
      licenses: ["MIT"],
      maintainers: ["Developer"],
      links: %{
        "GitHub" => "https://github.com/user/roarm",
        "Documentation" => "https://hexdocs.pm/roarm",
        "Waveshare RoArm-M2-S" => "https://www.waveshare.com/wiki/RoArm-M2-S"
      },
      files: ~w[lib guides mix.exs README.md CHANGELOG.md LICENSE],
      keywords: ["robotics", "roarm", "waveshare", "robot-arm", "uart", "serial", "hardware", "automation"]
    ]
  end

  defp docs do
    [
      main: "Roarm",
      name: "Roarm",
      source_url: "https://github.com/user/roarm",
      homepage_url: "https://github.com/user/roarm",
      extras: [
        "README.md",
        "CHANGELOG.md": [title: "Changelog"],
        "guides/getting-started.md": [title: "Getting Started"],
        "guides/hardware-setup.md": [title: "Hardware Setup"],
        "guides/commands.md": [title: "Command Reference"]
      ],
      groups_for_extras: [
        "Guides": ~r/guides\/.*/
      ],
      groups_for_modules: [
        "Core": [Roarm.Robot, Roarm.Communication],
        "Validation": [Roarm.CommandValidator],
        "Utilities": [Roarm.Demo, Roarm.Debug]
      ],
      groups_for_docs: [
        "Connection": &(&1[:group] == :connection),
        "Movement": &(&1[:group] == :movement),
        "LED Control": &(&1[:group] == :led),
        "Teaching": &(&1[:group] == :teaching),
        "Missions": &(&1[:group] == :missions)
      ],
      assets: %{
        "assets" => "assets"
      }
    ]
  end
end
