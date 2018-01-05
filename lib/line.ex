defmodule GitDiff.Line do
  @moduledoc """
  Every chunk contains multiple lines, which can be context, added, or removed lines.
  """
  
  defstruct type: nil, from_line_number: nil, to_line_number: nil, text: nil
end