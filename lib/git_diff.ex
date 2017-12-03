defmodule GitDiff do
  @moduledoc """
  This helper library takes the output from git commands and parses them into Elixir data structures.
  
  Currently only output from 'git diff' is supported.
  """
  
  alias GitDiff.Patch
  alias GitDiff.Chunk
  alias GitDiff.Line

  @doc """
  Parse the output from a 'git diff' command.
  
  Returns `{:ok, [%GitDiff.Patch{}]}` in case of success, `{:error, :unrecognized_format}` otherwise.
  """
  @spec parse_patch(String.t) :: {:ok, [%GitDiff.Patch{}]} | {:error, :unrecognized_format}
  def parse_patch(git_diff) do
    try do
      parsed_diff =
        git_diff
        |> String.splitter("\n")
        |> split_diffs()
        |> process_diffs()
        |> Enum.to_list()
        
      if Enum.all?(parsed_diff, fn(%Patch{} = _patch) -> true; (_) -> false end) do
        {:ok, parsed_diff}
      else
        {:error, :unrecognized_format}
      end
    rescue
      _ -> {:error, :unrecognized_format}
    end
  end
  
  defp process_diffs(diffs) do
    Stream.map(diffs, fn(diff) ->
      [headers | chunks] = split_diff(diff) |> Enum.to_list()
      patch = process_diff_headers(headers)
      
      chunks =
        Enum.map(chunks, fn(lines) ->
          process_chunk(%Chunk{}, lines)
        end)
      
      %{patch | chunks: chunks}
    end)
  end
  
  defp process_chunk(chunk, []), do: %{chunk | lines: Enum.reverse(chunk.lines)}
  
  defp process_chunk(chunk, ["" |lines]), do: process_chunk(chunk, lines)
  
  defp process_chunk(chunk, [line |lines]) do
    chunk =
      case line do
        "@@" <> line ->
          results = Regex.named_captures(~r/ -(?<from_start_line>[0-9]+),(?<from_num_lines>[0-9]+) \+(?<to_start_line>[0-9]+),(?<to_num_lines>[0-9]+) @@( (?<context>.+))?/, line)
          %{chunk | from_num_lines: results["from_num_lines"],
                    from_start_line: results["from_start_line"],
                    to_num_lines: results["to_num_lines"],
                    to_start_line: results["to_start_line"],
                    context: results["context"],
                    header: "@@" <> line
          }
        " " <> line -> %{chunk | lines: [%Line{line: line, type: :context} | chunk.lines]}
        "+" <> line -> %{chunk | lines: [%Line{line: line, type: :add} | chunk.lines]}
        "-" <> line -> %{chunk | lines: [%Line{line: line, type: :remove} | chunk.lines]}
      end
    
    process_chunk(chunk, lines)
  end
  
  defp process_diff_headers([header | headers]) do
    [_ | [diff_type | _]] = String.split(header, " ")
    
    if diff_type !== "--git" do
      raise "Invalid diff type"
    else
      process_diff_headers(%Patch{}, headers)
    end
  end
  
  defp process_diff_headers(patch, []), do: patch
  
  defp process_diff_headers(patch, [header | headers]) do
    patch =
      case header do
        "old mode " <> mode -> %{patch | headers: Map.put(patch.headers, "old mode", mode)}
        "new mode " <> mode -> %{patch | headers: Map.put(patch.headers, "new mode", mode)}
        "deleted file mode " <> mode -> %{patch | headers: Map.put(patch.headers, "deleted file mode", mode)}
        "new file mode " <> mode -> %{patch | headers: Map.put(patch.headers, "new file mode", mode)}
        "copy from mode " <> mode -> %{patch | headers: Map.put(patch.headers, "copy from mode", mode)}
        "copy to mode " <> mode -> %{patch | headers: Map.put(patch.headers, "copy to mode", mode)}
        "rename from mode " <> mode -> %{patch | headers: Map.put(patch.headers, "rename from mode", mode)}
        "rename to mode " <> mode -> %{patch | headers: Map.put(patch.headers, "rename to mode", mode)}
        "similarity index " <> number -> %{patch | headers: Map.put(patch.headers, "similarity index", number)}
        "dissimilarity index " <> number -> %{patch | headers: Map.put(patch.headers, "dissimilarity index", number)}
        "index " <> rest ->
          results = Regex.named_captures(~r/(?<first_hash>.+?)\.\.(?<second_hash>.+?) (?<mode>.+)/, rest)
          
          %{patch | headers: Map.put(patch.headers, "index", {results["first_hash"], results["second_hash"], results["mode"]})}
        "--- a/" <> from -> %{patch | from: from}
        "+++ b/" <> to -> %{patch | to: to}
      end
    
    process_diff_headers(patch, headers)
  end
  
  defp split_diff(diff) do
    chunk_fun =
      fn line, lines ->
        if String.starts_with?(line, "@@") do
          {:cont, Enum.reverse(lines), [line]}
        else
          {:cont, [line | lines]}
        end
       end
       
    after_fun =
      fn
        [] -> {:cont, []}
        lines -> {:cont, Enum.reverse(lines), []}
      end
    
    Stream.chunk_while(diff, [], chunk_fun, after_fun)
  end
  
  defp split_diffs(split_diff) do
    chunk_fun =
      fn line, lines ->
        if String.starts_with?(line, "diff") and lines != [] do
          {:cont, Enum.reverse(lines), [line]}
        else
          {:cont, [line | lines]}
        end
       end
       
    after_fun =
      fn
        [] -> {:cont, []}
        lines -> {:cont, Enum.reverse(lines), []}
      end
    
    Stream.chunk_while(split_diff, [], chunk_fun, after_fun)
  end
end
