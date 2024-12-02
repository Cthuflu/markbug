defmodule MarkbugTest.HeaderTest do
  use ExUnit.Case, async: true

  use MarkbugTest.ASTMatch

  test "atx #" do
    assert_ast "# foo bar", h(1, "foo bar")
    assert_ast "## foo bar", h(2, "foo bar")
    assert_ast "### foo bar", h(3, "foo bar")
    assert_ast "#### foo bar", h(4, "foo bar")
    assert_ast "##### foo bar", h(5, "foo bar")
    assert_ast "###### foo bar", h(6, "foo bar")

    assert_ast "####### foo bar", p("####### foo bar")
    assert_ast "# ###### foo bar", h(1, "###### foo bar")
    assert_ast "#tag", p("#tag")
  end

  test "setext ~w[=== ---]" do
    assert_ast """
    foo bar
    =======
    """, h(1, "foo bar")
    assert_ast """
    foo bar
    -------
    """, h(2, "foo bar")
  end
end
