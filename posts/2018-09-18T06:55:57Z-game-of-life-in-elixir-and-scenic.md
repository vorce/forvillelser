---
%{
  title: "Game of Life in Elixir and Scenic",
  description: "Writing game of life in Elixir with Scenic",
  created_at: "2018-09-18T06:55:57.531624Z"
}
---
After seeing Boyd Multerer's talk on an OpenGL backed UI framework for Elixir/Erlang last year I have been following its progress. This year at ElixirConf we got a new talk by Mr. Multerer with even more impressive and polished demos, and
most importantly the [Scenic repo](https://github.com/boydm/scenic) went public!

I knew I wanted to build something simple to get familiar with the framework. Yesterday I came up with the brilliant idea
to add a graphical view of my very old Elixir game of life *golex*. [Golex](https://github.com/vorce/golex) was one of my first Elixir projects, conceived back in 2013 when
Elixir was still in beta. I cloned the project, built it, and ran the text based simulation. Worked like a charm. I then looked around the code to see if it was
sufficiently modular for building a graphical view on top. Seemed so!

## Getting started with Scenic

This was pretty straightforward with clear instructions for macOS in the [Getting started guide](https://hexdocs.pm/scenic/getting_started.html). Didn't take
long at all before I was looking at the sample app and clicking around.

I created a new scene, and looked at the other ones for how to proceed.

## The grid

I decided to start by just drawing a 2d grid in my `GameOfLife` scene to get my feet wet.

First attempt:

```elixir
alias Scenic.Graph
alias Scenic.Primitives

@width 800
@height 600
@cell_size 10

@grid Graph.build()
  |> Primitives.line({{0, 0}, {@width, 0}}, stroke: {1, :white})
  |> Primitives.line({{0, @cell_size}, {@width, @cell_size}}, stroke: {1, :white})
  |> Primitives.line({{0, 2 * @cell_size}, {@width, 2 * @cell_size}}, stroke: {1, :white})
```

🤔

This is already old after three lines. I will write a function. Second attempt:

```elixir
def build_grid(graph, {width, height}, spacing) do
  horizontal =
    Enum.reduce(0..height, graph, fn y, acc ->
      acc
      |> Scenic.Primitives.line({{0, spacing * y}, {width, spacing * y}},
        stroke: {1, :white}
      )
    end)

  Enum.reduce(0..width, horizontal, fn x, acc ->
    acc
    |> Scenic.Primitives.line({{spacing * x, 0}, {spacing * x, height}},
      stroke: {1, :white}
    )
  end)
end

Graph.build()
|> build_grid({@width, @height}, @cell_size)
```

⏤ better! I actually found a bug with this function as I was writing this post ([proof](https://github.com/vorce/golux/commit/4b688b73f6332c4563eafe9e9bbf655b0d155e5f)). Here's the beautiful output: 
