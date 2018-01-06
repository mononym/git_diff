defmodule GitDiff.Line do
  @moduledoc """
  Every chunk contains multiple lines, which can be context, added, or removed lines.
  """
  
  @doc """
  Defines the Line struct.
  
  * :from_line_number - The line number preimage.
  * :to_line_number - The line number postimages.
  * :text - The text of this line.
  * :type - The extracted type of line. One of :context, :add, or :remove.
  """
  defstruct type: nil, from_line_number: nil, to_line_number: nil, text: nil
end