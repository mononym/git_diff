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
  @spec parse_patch(String.t(), Keyword.t()) ::
          {:ok, [%GitDiff.Patch{}]} | {:error, :unrecognized_format}
  def parse_patch(git_diff, opts \\ []) do
    try do
      parsed_diff =
        git_diff
        |> String.trim()
        |> String.splitter("\n")
        |> split_diffs()
        |> process_diffs(state(opts))
        |> Enum.to_list()

      {:ok, parsed_diff}
    catch
      :throw, {:git_diff, _reason} -> {:error, :unrecognized_format}
    end
  end

  @doc """
  Parse the output from a 'git diff' command.

  Like `parse_patch/1` but takes an `Enumerable` of lines and returns a stream
  of `{:ok, %GitDiff.Patch{}}` for successfully parsed patches or `{:error, _}`
  if the patch failed to parse.
  """
  @spec stream_patch(Enum.t(), Keyword.t()) :: Enum.t()
  def stream_patch(stream, opts \\ []) do
    stream
    |> Stream.map(&String.trim_trailing(&1, "\n"))
    |> split_diffs()
    |> process_diffs_ok(state(opts))
  end

  defp state(opts) do
    %{
      relative_from: opts[:relative_from] && Path.relative(opts[:relative_from]),
      relative_to: opts[:relative_to] && Path.relative(opts[:relative_to])
    }
  end

  defp process_diffs(diffs, state) do
    Stream.map(diffs, &process_diff(&1, state))
  end

  defp process_diffs_ok(diffs, state) do
    Stream.map(diffs, fn diff ->
      try do
        {:ok, process_diff(diff, state)}
      catch
        :throw, {:git_diff, _reason} -> {:error, :unrecognized_format}
      end
    end)
  end

  defp process_diff(diff, state) do
    [headers | chunks] = split_diff(diff) |> Enum.to_list()
    patch = process_diff_headers(headers, state)

    chunks =
      Enum.map(chunks, fn lines ->
        process_chunk(%{from_line_number: nil, to_line_number: nil}, %Chunk{}, lines)
      end)

    %{patch | chunks: chunks}
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

        other ->
          throw({:git_diff, {:invalid_chunk_line, other}})
      end

    process_chunk(context, chunk, lines)
  end

  defp process_diff_headers([header | headers], state) do
    case String.split(header, " ") do
      ["diff", "--git", "a/" <> file_a, "b/" <> file_b] ->
        process_diff_headers(
          %Patch{
            headers: %{"file_a" => file_a, "file_b" => file_b}
          },
          headers,
          state
        )

      _ ->
        throw({:git_diff, {:invalid_diff_type, header}})
    end
  end

  defp process_diff_headers(patch, [], _state), do: patch

  defp process_diff_headers(patch, [header | headers], state) do
    patch =
      case header do
        "old mode " <> mode ->
          %{
            patch
            | headers: Map.put(patch.headers, "old mode", mode),
              from: maybe_relative_to(patch.headers["file_a"], state.relative_to)
          }

        "new mode " <> mode ->
          %{
            patch
            | headers: Map.put(patch.headers, "new mode", mode),
              to: maybe_relative_to(patch.headers["file_b"], state.relative_to)
          }

        "deleted file mode " <> mode ->
          %{
            patch
            | headers: Map.put(patch.headers, "deleted file mode", mode),
              from: maybe_relative_to(patch.headers["file_a"], state.relative_to)
          }

        "new file mode " <> mode ->
          %{
            patch
            | headers: Map.put(patch.headers, "new file mode", mode),
              to: maybe_relative_to(patch.headers["file_b"], state.relative_to)
          }

        "copy from " <> file ->
          %{
            patch
            | headers:
                Map.put(
                  patch.headers,
                  "copy from",
                  maybe_relative_to(file, state.relative_to)
                ),
              from: maybe_relative_to(file, state.relative_to)
          }

        "copy to " <> file ->
          %{
            patch
            | headers:
                Map.put(
                  patch.headers,
                  "copy to",
                  maybe_relative_to(file, state.relative_to)
                ),
              from: maybe_relative_to(file, state.relative_to)
          }

        "rename from " <> file ->
          %{
            patch
            | headers:
                Map.put(
                  patch.headers,
                  "rename from",
                  maybe_relative_to_rename(file, state.relative_from)
                ),
              from: maybe_relative_to_rename(file, state.relative_from)
          }

        "rename to " <> file ->
          %{
            patch
            | headers:
                Map.put(
                  patch.headers,
                  "rename to",
                  maybe_relative_to_rename(file, state.relative_to)
                ),
              to: maybe_relative_to_rename(file, state.relative_to)
          }

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
          %{patch | from: maybe_relative_to(from_file(file), state.relative_from)}

        "+++ " <> file ->
          %{patch | to: maybe_relative_to(to_file(file), state.relative_to)}

        "Binary files " <> rest ->
          results = Regex.named_captures(~r/(?<from>.+?) and (?<to>.+?) differ/, rest)

          %{
            patch
            | from: maybe_relative_to(from_file(results["from"]), state.relative_from),
              to: maybe_relative_to(to_file(results["to"]), state.relative_to)
          }

        other ->
          throw({:git_diff, {:invalid_header, other}})
      end

    process_diff_headers(patch, headers, state)
  end

  defp from_file("a/" <> file), do: file
  defp from_file("/dev/null"), do: nil
  defp from_file(other), do: throw({:git_diff, {:invalid_from_filename, other}})

  defp to_file("b/" <> file), do: file
  defp to_file("/dev/null"), do: nil
  defp to_file(other), do: throw({:git_diff, {:invalid_to_filename, other}})

  defp maybe_relative_to(nil, _relative), do: nil
  defp maybe_relative_to(path, nil), do: path
  defp maybe_relative_to(path, relative), do: Path.relative_to(path, relative)

  defp maybe_relative_to_rename(path, nil), do: path
  defp maybe_relative_to_rename(path, relative), do: Path.relative_to(Path.relative(path), relative)

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
