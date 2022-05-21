---
%{
  title: "Code BEAM EU, Stockholm 2022",
  description: "Thoughts on this year's Code BEAM EU in Stockholm",
  created_at: "2022-05-21T15:12:03.145159Z"
}
---
I'm back home after two days at [Code BEAM EU in Stockholm](https://codesync.global/conferences/code-beam-sto-2022/). This was my first live conference experience since the pandemic started. And I almost forgot how good and inspiring in person conferences are. Don't get me wrong - virtual ones can be quite decent. It's just not the same, not even close.

Code BEAM EU was a hybrid event, so both live and virtual. The conference is focused on the BEAM, and the languages for it. Not surprisingly mostly Erlang and Elixir, but there was plenty of buzz for LFE and Gleam as well!

I've written some [conference blog posts](https://underthehood.meltwater.com/blog/2018/02/27/two-days-of-fun-at-lambda-days-2018/) before. I think it's a nice way to reflect, retain some knowledge and also to give thanks and credit to organizers and speakers. I'm not going to write about every talk I attended, just some of my highlights.

## Day 1

Sadly I missed the first keynote (Building Brilliant BEAM Teams by Sanne Kalkman), due to the train arriving a bit late.

I caught the **Update from the OTP Team** by Kenneth Lundin though. Some great things delivered in [OTP 25](https://github.com/erlang/otp/releases/tag/OTP-25.0). Biggest one I feel are:

- Selectable Features (EEP-60). There was a separate talk about this as well
- First experimental feature being the `maybe` expression, EEP-49 (basically elixir's `with` for erlang)

### The Hunt for the Cluster-Killer Bug (Dániel Szoboszlay)

Dániel gave us some serious war stories from Klarna and their internal erlang system called Kred. Always a pleasure hearing how real systems can fail, and how to fix them. I learned about [`sys.replace_state`](https://www.erlang.org/doc/man/sys.html#replace_state-2) and [`system_monitor`](https://github.com/klarna-incubator/system_monitor) ("a BEAM VM monitoring and introspection application that helps troubleshooting live systems.")

### Comparing the Actor Model and CSP Confurrency using Elixir and Clojure (Xiang Ji)

I have to highlight this talk by my colleague [Xiang Ji](https://xiangji.me/). Spot on overview and comparison on the these models, delivered in a super clear way. I personally really like both Clojure and Elixir but haven't actually needed to do much concurrency with Clojure, so this was a very nice talk for me. Big up!

### LiveView and JavaScript - A guide to achieving synergy (Michal Gibowski, Hamza Belhaj)

While [LiveView](https://github.com/phoenixframework/phoenix_live_view) allows us to sprinkle interactivity on our webapps without having to reach for JS. Many times this is not enough, and requiring server roundtrips seems unecessary for some things. Michal and Hamza explains what tools we have at our disposal to fuse the power of LiveView with JavaScript.

### Vaxine, the Rich-CRT Database for Elixir/Phoenix Applications (James Arthur)

This was a fun one. As a bit of a CRDT fanboy, I was instantly curious. Plus I've read a bit about Vaxine before this talk. [Vaxine](https://vaxine.io/) is a new database that almost sound too good to be true. It's still early but Arthur explained what they are trying to achieve and why its foundation on [AntidoteDB](https://github.com/AntidoteDB/antidote) and rich CRDTs are key. Looking forward to follow Vaxine's progress.

## Day 2

Lots of testing talks this day. Good ones!

But first the keynote "Backtracking through Time and Space in Erlang" by Quinn Wilton and Robert Virding. A nice mix of Erlang history and code snippets showing how cool Prolog is. Very inspiring. Although not really related to Prolog it made me want to pick up [Hoeg](https://github.com/vorce/hoeg/) development again :D

Next was the **Update from the Elixir Core Dev Team** by Andrea Leopardi. My highlights was the upcoming [PartitionSupervisor](https://hexdocs.pm/elixir/main/PartitionSupervisor.html) and the little inspect ergonomics improvements to make some data structures copy-pastable.

### Trace Specifications and Chaos Engineering: Advanced Testing with Snabbkaffe (Dmitrii Fedoseev)

Snabbkaffe!? Turns out it's a trace based testing framework. Which can do some really cool stuff that other techniques have a hard time with. For example testing distributed, eventually consistent systems. Apparently trace-based testing is used quite a bit in academia. Not so much in industry. [Snabbkaffe](https://github.com/klarna/snabbkaffe) might change that, at least for erlang/elixir users?

### Improve your tests with Makina (Luis Eduardo Bueso de Barrio)

Makina is a test library for elixir, it's compatible with the PropEr and QuickCheck state machine models. Makina's goal is to make it easier to write good state based property tests. The hope is to increase state based property test adoption in industry. Looks very nice, with a clean Elixir API. I wasn't able to find any code for Makina. So maybe it's still private? Will add a link if/when I find one.

Paper here: https://dl.acm.org/doi/abs/10.1145/3471871.3472964

### Kill All Mutants! (Dave Aronson)

Dave talked us through what mutation testing is, and how it works. Mutation testing helps you design new tests, and evaluate the quality of existing tests. Automated feedback about your tests. This is yet another technique (like trace based testing) I only heard about but never tried myself. Seems really good to have in the toolbox, and I do want to try this (maybe on [Dasie](https://github.com/vorce/dasie)?). [Muzak](https://github.com/devonestes/muzak) by [Devon Estes](https://www.devonestes.com/) looks like a good lib for Elixir for example.

## In closing

Amazing conference. Very high quality talks and speakers. Good vibes from attendees, and I met a bunch of cool people.

You know it's good when you learn a lot of new things, and leave exhausted but at the same time full of inspiration.

Thank you [Remote](https://remote.com) for giving me the possibility to attend! <3
