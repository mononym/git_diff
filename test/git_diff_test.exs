defmodule GitDiffTest do
  use ExUnit.Case
  import File

  test "parse a valid diff" do
    text = read!("test/diff.txt")
    {flag, _} = GitDiff.parse_patch(text)
    assert flag == :ok
  end

  test "stream a valid diff" do
    stream = stream!("test/diff.txt")
    Enum.to_list(GitDiff.stream_patch(stream))
  end

  test "parse an invalid diff" do
    dir = "test/bad_diffs"
    Enum.each(ls!(dir), fn(file) ->
      text = read!("#{dir}/#{file}")
      {flag, _} = GitDiff.parse_patch(text)
      assert flag == :error
    end)
  end

  test "stream an invalid diff" do
    dir = "test/bad_diffs"
    Enum.each(ls!(dir), fn(file) ->
      stream = stream!("#{dir}/#{file}")
      Enum.to_list(GitDiff.stream_patch(stream))
    end)
  end
end
