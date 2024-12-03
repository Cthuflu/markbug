defmodule MarkbugTest.ListTest do
  use ExUnit.Case, async: true

  use MarkbugTest.ASTMatch

  defp prefix(mark, str) when is_integer(mark) do
    <<mark::utf8, str::binary>>
  end
  defp prefix(mark, str) when is_binary(mark) do
    <<mark::binary, str::binary>>
  end

  test "unordered list marks" do
    for mark <- ~c[-*+] do
      assert_ast prefix(mark, " asdf"), ul(mark, true, [p("asdf")])
      assert_ast """
      #{prefix(mark, " foo")}
      #{prefix(mark, " bar")}
      #{prefix(mark, " baz")}
      #{prefix(mark, " biz")}
      """, ul(mark, [p("foo"), p("bar"), p("baz"), p("biz")])
    end
  end

  test "unordered nested list" do
    assert_ast """
    - level 1
      - level 2
      - continued level 2
        - level 3
        - continued level 3
    - continued level 1
    """, ul(?-, [
      [ p("level 1"),
        ul(?-, [
          p("level 2"),
          [
            p("continued level 2"),
            ul(?-, [
              p("level 3"),
              p("continued level 3")
            ])
          ]
        ])
      ],
      p("continued level 1")
    ])
  end

  test "ordered list marks" do
    for mark <- ~w[1 2 10 20 123456789] do
      assert_ast prefix(mark, ") asdf"), ol(mark, ?), [p("asdf")])
      assert_ast prefix(mark, ". asdf"), ol(mark, ?., [p("asdf")])
      assert_ast """
      #{prefix(mark, ") foo")}
      #{prefix(mark, ") bar")}
      #{prefix(mark, ") baz")}
      #{prefix(mark, ") biz")}
      """, ol(mark, ?), [p("foo"), p("bar"), p("baz"), p("biz")])
    end
  end

  test "ordered nested list" do
    assert_ast """
    1. level 1
       1. level 2
       2. continued level 2
          2. level 3
          3. continued level 3
    1. continued level 1
    """, ol("1", ?., [
      [ p("level 1"),
        ol("1", ?., [
          p("level 2"),
          [
            p("continued level 2"),
            ol("2", ?., [
              p("level 3"),
              p("continued level 3")
            ])
          ]
        ])
      ],
      p("continued level 1")
    ])

    assert_ast "1. 2. foo", ol("1", ?., [ol("2", ?., [p("foo")])])
  end

end
