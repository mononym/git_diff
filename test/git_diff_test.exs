defmodule GitDiffTest do
  use ExUnit.Case
  import File

  test "parse a valid diff" do
    text = read!("test/diff.txt")
    {flag, _} = GitDiff.parse_patch(text)
    assert flag == :ok
  end

  test "parse an invalid diff" do
    dir = "test/bad_diffs"
    Enum.each(ls!(dir), fn(file) ->
      text = read!("#{dir}/#{file}")
      {flag, _} = GitDiff.parse_patch(text)
      assert flag == :error
    end)
  end
end
