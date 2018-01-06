defmodule GitDiff.Patch do
  @moduledoc """
  Every 'git diff' command generates one or more patches.
  """
  
  @doc """
  Defines the Patch struct.
  
  * :from - The file name preimage.
  * :to - The file name postimages.
  * :headers - A list of headers for the patch.
  * :chunks - A list of chunks of changes contained in this patch. See `GitDiff.Chunk`.
  """
  defstruct from: nil, to: nil, headers: %{}, chunks: []
end