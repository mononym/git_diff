text = File.read!("test/good_diffs/diff.txt")

Benchee.run(
  %{
    "parse_patch" => fn -> GitDiff.parse_patch(text) end,
    "stream_patch" => fn -> text |> String.splitter("\n") |> GitDiff.stream_patch() |> Enum.to_list() end
  },
  memory_time: 2
)
