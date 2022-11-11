---
%{
  title: "Spawnfest - Kino Ecto (fka Lively)",
  description: "Spawnfest 2022 experience report",
  created_at: "2022-11-11T07:10:42.605138Z"
}
---

It's fall and that means [Spawnfest](https://spawnfest.org/)! I've appreciated this event for a while but haven't had the chance to participate before.

If you're not aware, Spawnfest is a fun BEAM based hackathon.

> SpawnFest is an annual 48 hour online software development contest in which teams from around the world get exactly one weekend to create the best BEAM-based applications they can. Special sponsorship brackets also exist for specific uses of BEAM-based technology.

## Lively (-> kino_ecto)

Me and some lovely folks (👋 Filipe, Vittoria, and Thiago) teamed up to hack on *Lively*. The initial idea was to build a nice Entity Relationship visualization of Ecto schemas for livebook. We managed to do that, and also some other really cool stuff!

[Lively](https://github.com/spawnfest/lively) got a bit of attention right away thanks to [Filipe's tweet](https://twitter.com/filipecabaco/status/1581786455688777728) about it. Even José Valim commented on it and suggested a name change. The continuation of the project now lives on as: **[kino_ecto](https://github.com/vorce/kino_ecto)**. Before the hackathon ended we had a collection of Ecto related utilities for livebook. Of course it's very much WIP/hackathon level code but the ideas are very interesting. Please check it out.

In this post I'll go in depth into the *KinoEco.Explain* functionality.

## SQL Explain

When trying to understand and debug slow queries [`explain`](https://www.postgresql.org/docs/current/sql-explain.html) is your best friend.
Naturally Ecto got you covered as well - [`Ecto.Adapters.SQL.explain/4`](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.html#explain/4).

Understanding the output from explain can be challenging though. To me a tool like [explain.dalibo](https://explain.dalibo.com/) helps immensely. But using dalibo requires uploading your plan to a third party. It makes the process a little slow, and might not always be a good idea.

What if you could get a nice, graphic visualization of a query explanation right inside [livebook](https://livebook.dev)?

## KinoEcto.Explain

*The KinoEcto API may change, there's no stable release yet.*

Enter `KinoEcto.Explain`! If you connect to an elixir node with `kino_ecto` added you can visualize a query simply by doing: `KinoEcto.explain(MyApp.Repo, :all, my_ecto_query)`

![KinoEcto.Explain in action](/assets/images/spawnfest-2022/lively_explain.png)

As you can see the output is inspired a lot by explain.dalibo :)

Now having lively installed on you production app might not be a great idea, but at least we can use it locally when debugging slow queries. What if we want to use a plan from production and render it in our local livebook? First we need to get a plan in a good format, here's the options I recommend for postgres:

```elixir
opts = [
    analyze: true,
    verbose: true,
    costs: true,
    settings: true,
    buffers: true,
    timing: true,
    summary: true,
    format: :map
  ]


plan = Ecto.Adapters.SQL.explain(MyApp.Repo, :all, myquery, opts)
```

Now we can copy the plan to our local livebook and render it with `KinoEcto.Explain.Postgres.new(plan)`.

There's a couple of things `KinoEcto.Explain` relies on to be able to build the graph:

* This is the biggest one: **PostgreSQL** ability to output the plan in a structured format. Sadly `KinoEcto.Explain` doesn't work with any of the other Ecto SQL adapters yet. I would love to fix that, and have started work on supporting MyXQL ([issue](https://github.com/vorce/kino_ecto/issues/2)).
* Mermaid graphs in markdown. Mermaid is so powerful, you can build all kinds of complex graphs. For explain we're using the [flowchart variant](https://mermaid-js.github.io/mermaid/#/flowchart).

High level flow:

1. Get explain output in structured format
1. Parse into a tree struct that keep the interesting bits (`KinoEcto.Explain.Postgres.Node.build_tree/1`)
1. Convert the tree into a top to bottom mermaid flowchart (`KinoEcto.Explain.Postgres.Renderer.build_mermaid_graph/1`)
1. Render to to livebook (`KinoEcto.Explain.Postgres.Renderer` implements [`Kino.Render`](https://github.com/livebook-dev/kino))

Available information on the nodes:

* Basics (node type, details)
* Metadata (cost, timing, rows)
* Warnings (heuristics, row under/over estimation only for now)

## Next steps for KinoEcto.Explain

Who knows really, but here's some things I'd like to do.

* Add a new warning for high % cost nodes
* Restructure code a bit to make it more consistent with the other utilites in Lively
* Take a look at [Kino.JS](https://hexdocs.pm/kino/Kino.JS.html) and/or [Kino.JS.Live](https://hexdocs.pm/kino/Kino.JS.Live.html) as replacements for the mermaid graph. While mermaid is really awesome it feels like it has some limitations, especially for the content rich nodes we need.
* Support for other Ecto adapters beside PostgreSQL

All in all I had a blast, learned a ton. Much love to the organizers, sponsors, and of course my awesome team mates!
