---
%{
  title: "Game of Life in Elixir and Scenic",
  description: "Writing game of life in Elixir with Scenic",
  created_at: "2018-09-18T06:55:57.531624Z"
}
---
After seeing Boyd Multerer's 2017 talk on Scenic – an OpenGL backed UI framework for Elixir/Erlang – I have been following its progress. This year at ElixirConf we got a [new talk by Mr. Multerer](https://youtu.be/1QNxLNMq3Uw) with even more impressive and polished demos, and
most importantly the [Scenic repo](https://github.com/boydm/scenic) went public.

I knew I wanted to build something simple to get familiar with the framework. Yesterday I came up with the brilliant idea
to add a graphical view of my very old Elixir game of life *golex*. [Golex](https://github.com/vorce/golex) was one of my first Elixir projects, conceived back in 2013 when
Elixir was still in beta (hipster cred?). I cloned the project, built it, and ran the text based simulation. Worked like a charm and the code looked modular enough to build a graphical view on top of.

### Getting started with Scenic

This was pretty straightforward with clear instructions for macOS in the [Getting started guide](https://hexdocs.pm/scenic/getting_started.html). It didn't take
long at all before I was looking at the sample app and clicking around.

I created a new scene, and looked at the other ones for clues on how to proceed.

### The grid

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

This is already old after three lines. I will write a function since I've heard that computers are good at executing repetitive tasks. Second attempt:

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
Graph.build()
|> build_grid({@width, @height}, @cell_size)
|> push_graph()
```

– that's better! I actually found a bug in this function as I was writing this post ([proof](https://github.com/vorce/golux/commit/4b688b73f6332c4563eafe9e9bbf655b0d155e5f)). Here's the beautiful output:

![golux grid](/assets/images/golux/grid.png)

### The cells

Since the grid drawing was so painless I was eager to get the cells out on the board. This turned out to also be
quite easy. I stared at the different [primitives](https://hexdocs.pm/scenic/Scenic.Primitives.html#summary) for a bit expecting something like `rect(x, y, width, height)` (like in [processing](https://processing.org/reference/rect_.html) or [quil](http://quil.info/api/shape/2d-primitives#rect)). I found [`quad/3`](https://hexdocs.pm/scenic/Scenic.Primitives.html#quad/3) instead. It wasn't really clear to me how to translate a rect at first, so I thought let's just go with quad now to Get Shit Done.

```elixir
def cell_graph(graph, %Golex.Cell{alive: false}), do: graph
def cell_graph(graph, %Golex.Cell{position: {x, y}, alive: true}) do
  xp = x * @cell_size
  yp = y * @cell_size

  Scenic.Primitives.quad(
    {{xp, yp}, {xp, yp + @cell_size}, {xp + @cell_size, yp + @cell_size}, {xp + @cell_size, yp}},
    fill: :white
  )
end
```

So there's a couple of things going on here. First off the pattern matching makes it really clear that we simply ignore dead cells. For alive cells we need to calculate where on the grid they should show up. That's what `xp` and `yp` is for (naming is hard etc). Now obviously we need to call this function for every single cell in our world.

```elixir
def world_graph(graph, %Golex.World{cells: cells}) do
  Enum.reduce(cells, graph, fn {_, cell}, acc ->
    cell_graph(acc, cell)
  end)
end

# init/2 can now do
world = Golex.random_world(...) # Get a new world from golex

Graph.build()
|> world_graph(world)
|> build_grid({@width, @height}, @cell_size)
|> push_graph()
```

We have the living cells on the grid, great. Except the game still sucks. We need to make it move.

### Animation

I'm sure there are a bunch of ways to do this but I really liked the idea of making the scene send a message to itself on a fixed interval, and that would trigger the world update + re-render. To achieve that we reach into our Erlang toolbox and find `:timer.send_interval/2` (also used in other Scenic demos). I figured that updating the scene once a second to start with should be conservative enough. I had no clue or expectations on how slow/fast scenic and golex would be.

To handle the message we have to implement `handle_info/2` – standard OTP stuff.

```elixir
# In init/2
:timer.send_interval(1_000, :world_tick)

def handle_info(:world_tick, state) do
  new_world = Golex.world_tick(state.world)

  Graph.build()
  |> world_graph(new_world)
  |> build_grid({@width, @height}, @cell_size)
  |> push_graph()

  {:noreply, %{state | world: new_world}}
end
```

#### It's slow :(

The one second update interval turned out to not be quite conservative enough. The updates looked a bit dodgy / not good. I measured how long it took
to do the stuff in `handle_info/2` above and it took a bit more than a second (~1.2). Was Scenic really
this slow? Of course not. It was golex' `world_tick/1` function that was very very naive – but I [fixed](https://github.com/vorce/golex/pull/1) that! Didn't worry about performance after that and could lower the timer interval a lot (to 100ms).

![Animated game of life](/assets/images/golux/golux.gif)

### Inputs

Part of the fun of game of life is seeing different starting conditions play out. So adding a way to restart the game with a fresh world would be cool. A simple left click on the board to do that maybe? I was a bit confused at first on how to implement this, because I kept trying to use [`filter_event/3`](https://hexdocs.pm/scenic/Scenic.Scene.html#c:filter_event/3). That was wrong because I don't have any components in my Scene. Components can generate *events*. In our case we need to deal with lower level *inputs* with [`handle_input/3`](https://hexdocs.pm/scenic/Scenic.Scene.html#c:handle_input/3). A nice way to understand what events are available and how to handle them is to add:

```elixir
def handle_input(msg, _, state) do
  IO.inspect(msg, label: "handle_input")
  {:noreply, state}
end
```

to your scene. This way every time some input event happen you will see how it looks. To handle mouse left click release I just pattern matched like this:

```elixir
def handle_input({:cursor_button, {:left, :release, _, _}}, _input_context, state) do
  IO.puts("Generating a new world")
  new_world = Golex.random_world(div(@width, @cell_size), div(@height, @cell_size))

  {:noreply, %{state | world: new_world}}
end
def handle_input(_msg, _, state), do: {:noreply, state} # Need to handle all other events
```

Voilà we have new worlds on left mouse click.

### Faster!

This section came about after getting some feedback from Mr. Multerer himself on [twitter](https://twitter.com/Octavorce/status/1042510733391679488). What happens with the performance if we switch the cell drawing from quads to rects?

![time difference for quads and rects](/assets/images/golux/quads_vs_rects.png)

| Percentile  | Quads (µs)  | Rects (µs)  |
| -----------:| -----------:| -----------:|
|         90  |    87123.5  |    82863.0  |
|         50  |    72575.5  |    70106.5  |

Rects with translation is a bit faster than quads, and probably better memory wise (although I haven't actually verified that). A note on the numbers here, they were gathered from a small sample size of 27 ticks for each type with [`timer.tc/1`](https://github.com/erlang/otp/edit/maint/lib/stdlib/doc/src/timer.xml#L260). What I measured was the time it took to update the game of life world and render with Scenic.

### Wrapping up

This turned out to be a fun way to get to know Scenic at least a little bit. I look forward to doing more with this promising framework.

Here's the code which is using `rect` instead of quads, and has some additional controls: [golux](https://github.com/vorce/golux)
