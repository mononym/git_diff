defmodule GitDiff.Patch do
  @moduledoc false
  
  defstruct from: nil, to: nil, headers: %{}, chunks: []
end