defmodule GitDiff.Chunk do
  @moduledoc false
  
  defstruct from_start_line: nil, from_num_lines: nil, to_start_line: nil, to_num_lines: nil, header: nil, lines: [], context: nil
end