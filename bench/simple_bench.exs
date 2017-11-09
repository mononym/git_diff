defmodule GitDiff.SimpleBench do
  use Benchfella

  @text File.read!("test/diff.txt")

  bench "parse diff" do
    GitDiff.parse_patch!(@text)
  end
end