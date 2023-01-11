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

  test "relative_from and relative_to adjust patch dirs" do
    {:ok, patch} =
      stream!("test/diff.txt")
      |> GitDiff.stream_patch(relative_to: "/tmp/foo", relative_from: "/tmp/foo")
      |> Enum.to_list()
      |> List.last()

    assert patch.from == "package-phx_new-1.0.0-BD5E394E/my_app/web/static/assets/favicon.ico"
    assert patch.to == "package-phx_new-1.5.7-086C1921/my_app/assets/static/favicon.ico"
    assert patch.headers["rename from"] == "package-phx_new-1.0.0-BD5E394E/my_app/web/static/assets/favicon.ico"
    assert patch.headers["rename to"] == "package-phx_new-1.5.7-086C1921/my_app/assets/static/favicon.ico"
  end

  test "reads renames" do
    {:ok, patch} =
      stream!("test/diff.txt")
      |> GitDiff.stream_patch()
      |> Enum.to_list()
      |> List.last()

    assert patch.from == "/tmp/foo/package-phx_new-1.0.0-BD5E394E/my_app/web/static/assets/favicon.ico"
    assert patch.to == "/tmp/foo/package-phx_new-1.5.7-086C1921/my_app/assets/static/favicon.ico"
    assert patch.headers["rename from"] == "/tmp/foo/package-phx_new-1.0.0-BD5E394E/my_app/web/static/assets/favicon.ico"
    assert patch.headers["rename to"] == "/tmp/foo/package-phx_new-1.5.7-086C1921/my_app/assets/static/favicon.ico"
  end

  test "reads new files without content" do
    {:ok, patch} =
      stream!("test/diff_no_changes_new_file.txt")
      |> GitDiff.stream_patch()
      |> Enum.to_list()
      |> List.last()

    assert patch.from == nil
    assert patch.to == "/file_1.txt"
    assert patch.headers["file_a"] == "file_1.txt"
    assert patch.headers["file_b"] == "file_1.txt"
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
