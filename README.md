# Markbug

A fast markdown parser in pure Elixir, without using regular expressions.

The parser, as of testing, is 10x faster than `Earmark` for longer documents; 
with comparable performance to `MDex`, a Rust NIF.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `markbug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:markbug, "~> 0.9.0"}
  ]
end
```

## Basic Usage

```elixir
iex> Markbug.ast("""
# Foo Bar

_According to all known laws of aviation_, *there is no way a bee should be able to fly*.
""")

{:ok,
 [
   {:header, 1, [text: "Foo Bar"]},
   {:p,
    [
      {:em, 95, ["According to all known laws of aviation"]},
      ", ",
      {:em, 42, ["there is no way a bee should be able to fly"]},
      "."
    ]}
 ]}
```

```elixir
iex> Markbug.html("""
# Foo Bar
 
_According to all known laws of aviation_, *there is no way a bee should be able to fly*.
""")

[
  ["<", "article", ">"],
  [
    [["<", "h1", ">"], ["Foo Bar"], ["</", "h1", ">"]],
    [
      ["<", "p", ">"],
      [
        [
          ["<", "i", ">"],
          ["According to all known laws of aviation"],
          ["</", "i", ">"]
        ],
        ", ",
        [
          ["<", "b", ">"],
          ["*", ["there is no way a bee should be able to fly"], "*"],
          ["</", "b", ">"]
        ],
        "."
      ],
      ["</", "p", ">"]
    ]
  ],
  ["</", "article", ">"]
]
```

## Notes

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/markbug>.

