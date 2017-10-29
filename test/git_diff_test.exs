defmodule GitDiffTest do
  use ExUnit.Case
  doctest GitDiff

  test "greets the world" do
    text = File.read!("test/diff.txt")
    assert GitDiff.parse_patch!(text) == nil
  end
end
