defmodule MarkbugTest.InlineTest do
  use ExUnit.Case, async: true
  doctest Markbug

  test "star emphasis" do
    assert Markbug.ast("*asdf*") == {:ok, [{:em, ?*, ["asdf"]}]}
    assert Markbug.ast("*foo*bar*") == {:ok, [{:em, ?*, ["foo"]}, {:p, ["bar", "*"]}]}
    assert Markbug.ast("*foo*bar") == {:ok, [{:em, ?*, ["foo"]}, {:p, ["bar"]}]}
  end

  test "star strong" do
    assert Markbug.ast("**asdf**") == {:ok, [{:strong, ?*, ["asdf"]}]}
  end

  test "underscore emphasis" do
    assert Markbug.ast("_asdf_") == {:ok, [{:em, ?_, ["asdf"]}]}
    assert Markbug.ast("_foo_bar_") == {:ok, [{:em, ?_, ["foo", "_", "bar"]}]}
    assert Markbug.ast("_foo_bar") == {:ok, [{:p, ["_", "foo", "_", "bar"]}]}
  end

  test "underscore strong" do
    assert Markbug.ast("__asdf__") == {:ok, [{:strong, ?_, ["asdf"]}]}
    assert Markbug.ast("__foo_bar__") == {:ok, [{:strong, ?_, ["foo", "_", "bar"]}]}
    assert Markbug.ast("__foo_bar") == {:ok, [{:p, ["_", "_", "foo", "_", "bar"]}]}
  end

  test "code span" do
    assert Markbug.ast("`asdf`") == {:ok, [p: [{:code_span, "asdf"}]]}
    assert Markbug.ast("`foo *bar* baz`") == {:ok, [p: [{:code_span, "foo *bar* baz"}]]}
    assert Markbug.ast("`foo bar baz") == {:ok, [p: ["`", "foo bar baz"]]}
    assert Markbug.ast("`foo *bar* baz") == {:ok, [p: ["`", "foo ", {:em, ?*, ["bar"]}, " baz"]]}

    assert Markbug.ast("``asdf``") == {:ok, [p: [{:code_span, "asdf"}]]}
    assert Markbug.ast("``foo bar baz``") == {:ok, [p: [{:code_span, "foo bar baz"}]]}
    assert Markbug.ast("``foo bar baz`") == {:ok, [p: ["``", "foo bar baz", "`"]]}
  end

  test "tilde em" do
    assert Markbug.ast("~~asdf~~") == {:ok, [{:em, "~~", ["asdf"]}]}
    assert Markbug.ast("~~foo~bar~~") == {:ok, [{:em, "~~", ["foo~bar"]}]}
    assert Markbug.ast("~~foo~bar") == {:ok, [{:p, ["~~", "foo~bar"]}]}
  end

  test "pipe em" do
    assert Markbug.ast("||asdf||") == {:ok, [{:em, "||", ["asdf"]}]}
    assert Markbug.ast("||foo|bar||") == {:ok, [{:em, "||", ["foo|bar"]}]}
    assert Markbug.ast("||foo|bar") == {:ok, [{:p, ["||", "foo|bar"]}]}
  end

end
