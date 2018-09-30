---
%{
  title: "Creating a statically generated site - the hard way",
  description: "How not to make your own static site",
  created_at: "2018-09-07T15:33:46.718356Z"
}
---
Forget about installing Jekyll, Next, Hugo, or any of the other mainstream
static site generators out there. To make Förvillelser I opted for the Carl Sagan method:

> If you wish to make apple pie from scratch, you must first create the universe

I knew that I wanted a site generator that I could mess around with properly.
Right now I am very fond of [Elixir](https://elixir-lang.org/) so naturally I looked at the elixir options out there.
[Obelisk](https://github.com/BennyHallett/obelisk) immediately caught my attention because of its nice `mix` task UX.
I followed the README to create my site, and I hit the first road block right away.
Obelisk didn't build out of the box. No problem, I updated one of its dependencies and continued.
Next I tried to build my site, this time obelisk crashed and it wasn't obvious why.
That prompted me to look closer on its github page – maybe someone else had the same problem? Uh oh, lots of PRs with no attention, and the project seemed generally abandoned by its creator.
One guy even wanted to take over the project but hadn't gotten a response :(

Okay. That messed up my plan, since if I hack on this thing I'd like to give the result back
to the community. Or at least have the option to do so. Forking seemed unfun, as did the prospect of debugging and fixing. Looked at [Serum](https://github.com/Dalgona/Serum) as well. Nice but not
quite what I was after. Oh well time to roll up my sleeves and get cranking on My Own Static Site Generator!
How hard can it be!? Haha!

I, as a software developer by trade, of course had some requirements. First I wanted
my new shiny sites pages and posts to be written in Markdown. I wanted these documents
to be versioned controlled. And I wanted to be able to deploy changes to my site with git commit+push.

Nothing out of the ordinary.

I got a first good enough version of [Gonz](https://github.com/vorce/gonz) together in an evening or so. I started working on [Förvillelser](https://github.com/vorce/forvillelser)
early so that I could feed the Gonz development with fixes and features I needed for my particular site.

After a few more days of sporadic hacking I realized that I needed to publish Förvillelser somewhere to actually deliver value to my customer (me). Around this time other requirements popped up in my head:

- I want SSL on the thing. `http` without `s` is so lame!
- I don't want to actually run a server myself. All the dev without the ops for this please.

With these in mind it seemed my choices were either [github pages](https://pages.github.com/) or [netlify](https://www.netlify.com/). I really liked
the prospect of not having the baked HTML files in my repo, only the raw markdown files. Not sure why, I guess something something tidy, ridiculous nerd bullshit. That meant using netlify, because they can build the site for you. Cool beans 😎

I signed up and set up my site. Boom – "Site deploy failed": `make: mix: Command not found`.
Not sure why I expected them to support Elixir out of the box, but hey a guy can dream.
Started looking around for some neat workaround or whatever. No real luck, but I did find [netlify's build-image](https://github.com/netlify/build-image) repo – all open source and beautiful.
I forked that, added erlang and elixir and sent a [PR](https://github.com/netlify/build-image/pull/188).
Surprisingly it was approved (eventually) and even merged to master!

### In conclusion

1. Build your own static site generator in a non-mainstream programming language X
2. Build the actual site
3. Deploy the site somewhere that doesn't support X
4. Contribute changes to that place's stack to add support for X
5. P R O F I T 🎉
