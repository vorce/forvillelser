---
%{
  title: "Game of Life in Elixir and Scenic",
  description: "Writing game of life in Elixir with Scenic",
  created_at: "2018-09-18T06:55:57.531624Z"
}
---
After seeing Boyd Multerer's talk on Scenic ⏤ an OpenGL backed UI framework for Elixir/Erlang ⏤ I have been following its progress. This year at ElixirConf we got a [new talk by Mr. Multerer](https://youtu.be/1QNxLNMq3Uw) with even more impressive and polished demos, and
most importantly the [Scenic repo](https://github.com/boydm/scenic) went public!

I knew I wanted to build something simple to get familiar with the framework. Yesterday I came up with the brilliant idea
to add a graphical view of my very old Elixir game of life *golex*. [Golex](https://github.com/vorce/golex) was one of my first Elixir projects, conceived back in 2013 when
Elixir was still in beta (hipster cred?). I cloned the project, built it, and ran the text based simulation. Worked like a charm! I then looked around the code to see if it was
sufficiently modular for building a graphical view on top. Affirmative, let's go.

## Getting started with Scenic

This was pretty straightforward with clear instructions for macOS in the [Getting started guide](https://hexdocs.pm/scenic/getting_started.html). It didn't take
long at all before I was looking at the sample app and clicking around.

I created a new scene, and looked at the other ones for clues on how to proceed.

## The grid

I decided to start by just drawing a 2D grid in my `GameOfLife` scene to get my feet wet.

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

This is already old after three dumb lines. I will write a function since I've heard that computers are good at executing repetetive tasks. Second attempt:

```elixir
def build_grid(graph, {width, height}, spacing) do
  horizontal =
    Enum.reduce(0..height, graph, fn y, acc ->
      Scenic.Primitives.line(acc, {{0, spacing * y}, {width, spacing * y}}, stroke: {1, :white})
    end)

  Enum.reduce(0..width, horizontal, fn x, acc ->
    Scenic.Primitives.line(acc, {{spacing * x, 0}, {spacing * x, height}}, stroke: {1, :white})
  end)
end

# in init/2
build_grid(Graph.build(), {@width, @height}, @cell_size)
```

⏤ better! I actually found a bug in this function as I was writing this post ([proof](https://github.com/vorce/golux/commit/4b688b73f6332c4563eafe9e9bbf655b0d155e5f)). Here's the beautiful output: 

![golux grid](/assets/images/golux_grid.png)

## The cells

## Animation

## Inputs

Part of the fun of game of life is seeing different starting conditions play out. So adding a way to restart the game with a fresh world would be cool. Left clicking the board would be a good enough way to trigger that I figured. I was a bit confused at first on how to implement this, because I kept trying to use [`filter_event/3`](https://hexdocs.pm/scenic/Scenic.Scene.html#c:filter_event/3). That was wrong because I don't have any components in my Scene ⏤ instead I have to use [`handle_input/3`](https://hexdocs.pm/scenic/Scenic.Scene.html#c:handle_input/3). A nice way to understand what events are available and how to handle them is to add:

```elixir
def handle_input(msg, _, state) do
  IO.inspect(msg, label: "handle_input")
  {:noreply, state}
end
```

to your scene. This way everytime some input event happens you will see how it looks. To handle mouse left click release I just pattern matched like this:

```elixir
def handle_input({:cursor_button, {:left, :release, _, _}}, _input_context, state) do
  IO.puts("Generating a new world")
  new_world = Golex.random_world(div(@width, @cell_size), div(@height, @cell_size))
  render_game(new_world)

  {:noreply, %{state | world: new_world}}
end
```

## Wrapping up

Here's the final result: [golux](https://github.com/vorce/golux)