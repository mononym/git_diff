# GitDiff

A simple, naive implementation for taking the output from 'git diff' and transforming it into Elixir structs.

## Installation

The package can be installed by adding `git_diff` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:git_diff, "~> 0.2.0"}
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
        context: "class Cursor extends Model {",
        lines: [
          %GitDiff.Line{
            line: "  {",
            type: :context # will be one of :context, :add, :delete
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
code, while naive, is less than 100 lines of actual code and it's painfully obvious where the output data structure is
constructed so it should be easy to discover the answer to any questions about how something will look. Or you could run
it against the `diff.txt` file in the `test` directory for some quick viewing of the output.

## Benchmarks

Haven't done much benchmarking, but up to around a 5k (I just stopped trying there) line diff the performance was
linear and took a whopping 35ms per call on the test VM. For a more reasonably sized ~150 line diff it clocked in at
around 340 microseconds.