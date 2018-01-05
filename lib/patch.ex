defmodule GitDiff.Patch do
  @moduledoc """
  Every 'git diff' command generates one or more patches.
  """
  
  defstruct from: nil, to: nil, headers: %{}, chunks: []
end