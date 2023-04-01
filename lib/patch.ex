defmodule GitDiff.Patch do
  @moduledoc """
  Every 'git diff' command generates one or more patches.
  """

  @typedoc """
  Defines the Patch struct.

  * :from - The file name preimage.
  * :to - The file name postimages.
  * :headers - A list of headers for the patch.
  * :chunks - A list of chunks of changes contained in this patch. See `GitDiff.Chunk`.
  """
  @type t :: %__MODULE__{
    from: String.t() | nil,
    to: String.t() | nil,
    headers: %{String.t() => String.t()},
    chunks: [GitDiff.Chunk.t()]
  }

  defstruct from: nil, to: nil, headers: %{}, chunks: []
end
