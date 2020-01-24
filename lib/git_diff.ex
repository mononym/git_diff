defmodule GitDiff do
  @moduledoc """
  A simple implementation for taking the output from 'git diff' and transforming it into Elixir structs.

  ## Installation

  The package can be installed by adding `git_diff` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:git_diff, "~> 0.6.1"}
    ]
  end
  ```

  ## Example

  Output:
  ```
  [
    %GitDiff.Patch{
      chunks: [
        %GitDiff.Chunk{
          from_num_lines: "42",
          from_start_line: "42",
          header: "@@ -481,23 +483,24 @@ class Cursor extends Model {"
          context: "class Cursor extends Model {", # will be "" if there is no context
          lines: [
            %GitDiff.Line{
              from_line_number: 481,
              text: "   {",
              to_line_number: 483,
              type: :context # will be one of :context, :add, :remove
            },
            ...
          ],
          to_num_lines: "42",
          to_start_line: "42"
        }
      ],
    from: "src/cursor.js",
    headers: %{"index" => {"10bdef8", "181eeb9", "100644"}},
    to: "src/cursor.js"},
  ]
  ```

  The above output is heavily truncated for illustration, but it should give enough of an idea of what to expect. The
  code, while naive, is less than 100 lines of actual code and all takes place in the GitDiff module. Emulate the tests
  in a an interactive shell for quick viewing of the output.

  ## Benchmarks

  Haven't done much benchmarking, but up to around a 5k (I just stopped trying there) line diff the performance was
  linear and took a whopping 35ms per call on the test VM. For a more reasonably sized ~150 line diff it clocked in at
  around 340 microseconds.
  """

  alias GitDiff.Patch
  alias GitDiff.Chunk
  alias GitDiff.Line

  @doc """
  Parse the output from a 'git diff' command.

  Returns `{:ok, [%GitDiff.Patch{}]}` for success, `{:error, :unrecognized_format}` otherwise. See `GitDiff.Patch`.
  """
  @spec parse_patch(String.t()) :: {:ok, [%GitDiff.Patch{}]} | {:error, :unrecognized_format}
  def parse_patch(git_diff) do
    try do
      parsed_diff =
        git_diff
        |> String.trim()
        |> String.splitter("\n")
        |> split_diffs()
        |> process_diffs()
        |> Enum.to_list()

      if Enum.all?(parsed_diff, fn
           %Patch{} = _patch -> true
           _ -> false
         end) do
        {:ok, parsed_diff}
      else
        {:error, :unrecognized_format}
      end
    rescue
      _ -> {:error, :unrecognized_format}
    end
  end

  defp process_diffs(diffs) do
    Stream.map(diffs, fn diff ->
      [headers | chunks] = split_diff(diff) |> Enum.to_list()
      patch = process_diff_headers(headers)

      chunks =
        Enum.map(chunks, fn lines ->
          process_chunk(%{from_line_number: nil, to_line_number: nil}, %Chunk{}, lines)
        end)

      %{patch | chunks: chunks}
    end)
  end

  defp process_chunk(_, chunk, []) do
    %{chunk | lines: Enum.reverse(chunk.lines)}
  end

  defp process_chunk(context, chunk, ["" | lines]), do: process_chunk(context, chunk, lines)

  defp process_chunk(context, chunk, [line | lines]) do
    {context, chunk} =
      case line do
        "@@" <> text ->
          results =
            Regex.named_captures(
              ~r/ -(?<from_start_line>[0-9]+)(,(?<from_num_lines>[0-9]+))? \+(?<to_start_line>[0-9]+)(,(?<to_num_lines>[0-9]+))? @@( (?<context>.+))?/,
              text
            )

          {%{
             context
             | from_line_number: String.to_integer(results["from_start_line"]),
               to_line_number: String.to_integer(results["to_start_line"])
           },
           %{
             chunk
             | from_num_lines: results["from_num_lines"],
               from_start_line: results["from_start_line"],
               to_num_lines: results["to_num_lines"],
               to_start_line: results["to_start_line"],
               context: results["context"],
               header: "@@" <> text
           }}

        " " <> _ = text ->
          line = %Line{
            text: text,
            type: :context,
            to_line_number: Integer.to_string(context.to_line_number),
            from_line_number: Integer.to_string(context.from_line_number)
          }

          {
            %{
              context
              | to_line_number: context.to_line_number + 1,
                from_line_number: context.from_line_number + 1
            },
            %{chunk | lines: [line | chunk.lines]}
          }

        "+" <> _ = text ->
          line = %Line{
            text: text,
            type: :add,
            to_line_number: Integer.to_string(context.to_line_number)
          }

          {
            %{context | to_line_number: context.to_line_number + 1},
            %{chunk | lines: [line | chunk.lines]}
          }

        "-" <> _ = text ->
          line = %Line{
            text: text,
            type: :remove,
            from_line_number: Integer.to_string(context.from_line_number)
          }

          {
            %{context | from_line_number: context.from_line_number + 1},
            %{chunk | lines: [line | chunk.lines]}
          }

        "\\" <> _ = text ->
          line = %Line{
            text: text,
            type: :context
          }

          {
            context,
            %{chunk | lines: [line | chunk.lines]}
          }
      end

    process_chunk(context, chunk, lines)
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
        "old mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "old mode", mode)}

        "new mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "new mode", mode)}

        "deleted file mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "deleted file mode", mode)}

        "new file mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "new file mode", mode)}

        "copy from mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "copy from mode", mode)}

        "copy to mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "copy to mode", mode)}

        "rename from " <> filepath ->
          %{patch | headers: Map.put(patch.headers, "rename from", filepath), from: filepath}

        "rename from mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "rename from mode", mode)}

        "rename to " <> filepath ->
          %{patch | headers: Map.put(patch.headers, "rename to", filepath), to: filepath}

        "rename to mode " <> mode ->
          %{patch | headers: Map.put(patch.headers, "rename to mode", mode)}

        "similarity index " <> number ->
          %{patch | headers: Map.put(patch.headers, "similarity index", number)}

        "dissimilarity index " <> number ->
          %{patch | headers: Map.put(patch.headers, "dissimilarity index", number)}

        "index " <> rest ->
          results =
            Regex.named_captures(~r/(?<first_hash>.+?)\.\.(?<second_hash>.+?) (?<mode>.+)/, rest)

          %{
            patch
            | headers:
                Map.put(
                  patch.headers,
                  "index",
                  {results["first_hash"], results["second_hash"], results["mode"]}
                )
          }

        "--- " <> file ->
          %{patch | from: from_file(file)}

        "+++ " <> file ->
          %{patch | to: to_file(file)}

        "Binary files " <> rest ->
          results = Regex.named_captures(~r/(?<from>.+?) and (?<to>.+?) differ/, rest)

          %{patch | from: from_file(results["from"]), to: to_file(results["to"])}
      end

    process_diff_headers(patch, headers)
  end

  defp from_file("a/" <> file), do: file
  defp from_file("/dev/null"), do: nil

  defp to_file("b/" <> file), do: file
  defp to_file("/dev/null"), do: nil

  defp split_diff(diff) do
    chunk_fun = fn line, lines ->
      if String.starts_with?(line, "@@") do
        {:cont, Enum.reverse(lines), [line]}
      else
        {:cont, [line | lines]}
      end
    end

    after_fun = fn
      [] -> {:cont, []}
      lines -> {:cont, Enum.reverse(lines), []}
    end

    Stream.chunk_while(diff, [], chunk_fun, after_fun)
  end

  defp split_diffs(split_diff) do
    chunk_fun = fn line, lines ->
      if String.starts_with?(line, "diff") and lines != [] do
        {:cont, Enum.reverse(lines), [line]}
      else
        {:cont, [line | lines]}
      end
    end

    after_fun = fn
      [] -> {:cont, []}
      lines -> {:cont, Enum.reverse(lines), []}
    end

    Stream.chunk_while(split_diff, [], chunk_fun, after_fun)
  end
end
