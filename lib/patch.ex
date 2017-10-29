defmodule GitDiff.Patch do
  defstruct from: nil, to: nil, headers: %{}, chunks: []
end