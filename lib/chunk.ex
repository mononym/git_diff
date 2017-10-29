defmodule GitDiff.Chunk do
  defstruct from_start_line: nil, from_num_lines: nil, to_start_line: nil, to_num_lines: nil, header: nil, lines: []
end