---
%{
  title: "Game of Life in Elixir and Scenic",
  description: "Writing game of life in Elixir with Scenic",
  created_at: "2018-09-18T06:55:57.531624Z"
}
---
After seeing Boyd Multerer's talk on a native (OpenGL backed) UI framework for Elixir/Erlang last year I have been
trying to follow its progress. This year at ElixirConf we got a new talk with even more impressive and polished demos, and
most importantly the [Scenic repo](https://github.com/boydm/scenic) went public!

I knew I wanted to build something simple to get familiar with the framework. Yesterday I came up with the brilliant idea
to add a graphical view of my very old Elixir game of life. [Golex](https://github.com/vorce/golex) was one of my first Elixir projects, written back in 2013 when
Elixir was still in beta. I cloned the project, built it, and ran the text based simulation. Worked like a charm. I then looked around the code to see if it was
sufficiently modular for building a graphical view ontop.