defmodule MarkbugTest.InlineTest do
  use ExUnit.Case, async: true
  doctest Markbug

  use MarkbugTest.ASTMatch

  test "star emphasis" do
    assert_ast "*asdf*", p(em(?*, "asdf"))
    assert_ast "*foo*bar*", p([em(?*, "foo"), "bar*"])
    assert_ast "*foo*bar", p([em(?*, "foo"), "bar"])
    assert_ast "*foo *bar*", p(["*foo ", em(?*, "bar")])
  end

  test "star strong" do
    assert_ast "**asdf**", p(strong(?*, "asdf"))
  end

  test "underscore emphasis" do
    assert_ast "_asdf_", p(em(?_, "asdf"))
    assert_ast "_foo_bar_", p(em(?_, "foo_bar"))
    assert_ast "_foo_bar", p("_foo_bar")
  end

  test "underscore strong" do
    assert_ast "__asdf__", p(strong(?_, "asdf"))
    assert_ast "__foo_bar__", p(strong(?_, "foo_bar"))
    assert_ast "__foo_bar", p("__foo_bar")
  end

  test "code span" do
    assert_ast "`asdf`", p(code_span("asdf"))
    assert_ast "`foo *bar* baz`", p(code_span("foo *bar* baz"))
    assert_ast "`foo bar baz", p("`foo bar baz")
    assert_ast "`foo *bar* baz", p(["`foo ", em(?*, "bar"), " baz"])
    assert_ast "`foo _bar_ baz", p(["`foo ", em(?_, "bar"), " baz"])

    assert_ast "``asdf``", p(code_span("asdf"))
    assert_ast "``foo bar baz``", p(code_span("foo bar baz"))
    assert_ast "``foo bar baz`", p("``foo bar baz`")
  end

  test "tilde em" do
    assert_ast "~~asdf~~", p(em("~~", "asdf"))
    assert_ast "~~foo~bar~~", p(em("~~", "foo~bar"))
    assert_ast "~~foo~bar", p("~~foo~bar")
  end

  test "pipe em" do
    assert_ast "||asdf||", p(em("||", "asdf"))
    assert_ast "||foo|bar||", p(em("||", "foo|bar"))
    assert_ast "||foo|bar", p("||foo|bar")
  end

end
