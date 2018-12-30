---
%{
  title: "On Designing Data-Intensive Applications",
  description: "A kind of review of the book by Marting Kleppmann",
  created_at: "2018-12-30T12:39:52.518240Z"
}
---
Designing Data-Intensive Applications -- The big ideas behind reliable, scalable, and maintainable systems -- is a book written by [Martin Kleppmann](http://martin.kleppmann.com/), published in 2017 by O'reilly.

I read this book cover-to-cover, which is probably not necessary or even recommended. But it worked quite well for me, although it took a long time to finish. Towards the end of the book
I started thinking about writing a sort of review of it. Partly to make some of the ideas and concepts stick better, and partly because I think it's a great book that more people should read.

While reading technical books I usually make markings on sections I like to get back to. Either to
re-read, or maybe as a starting point for a small experiment of my own, or just because the page/section
is really good. In this post I'll write a short snippet about each such marking I made for [Designing Data-Intensive Applications](http://dataintensive.net/).

My expectations on the book was different than the actual content. I had the impression that
DD-IA was going to be more like cookbook style read, recipes on how to architect scalable backend apps.
That is not the case at all, instead the book focuses on the underlying theory for vital pieces
used in such designs. Things like how database features work under the hood, theories for distributed systems, concurrency truths, and tradeoffs around consistency, fault tolerance etc. You might think "why should I care about stuff like that?". My answer is that this sort of stuff give you guidance on what technology to chose for certain use-cases, and what characteristics you can expect from it.
Plus it's great material if you ever want to build some database like system yourself.

## My markings

### Constructing and maintaining SSTables

*Where:* Page 78, Chapter 3: Storage and retrieval

I think my main motivation for marking this section is that it clearly outlines how some storage engines work. It describes an algorithm that is "essentially what is used in LevelDB and RocksDB"!
Also cool that red-black trees are mentioned as a good way to store a sorted structure in memory for a storage engine. I quite recently implemented a persistent [red-black tree in Elixir](https://github.com/vorce/dasie) myself.

### Partitioning and Secondary Indexes

*Where:* Page 206, Chapter 6: Partitioning

My interest in search engines triggered this marking. Here we get a deep dive into
why secondary indexes are so useful, how they can be implemented, and some tradeoffs.

I really like the way Kleppmann makes it easy to understand how partitioning affect secondary indexes.
And how the scatter/gather approach suffers from some issues with tail latency amplification (all too familiar after having worked on Elasticsearch backed projects).

### Preventing Lost Updates

*Where:* Page 242, Chapter 7: Transactions

Description of the very common issue of data loss due to concurrent updates; where you read a value, (possibly) modify it and then write it back. Then follows a list of solutions to the problem with plenty of details:

- Atomic write operations
- Explicit locking
- Automatically detecting lost updates
- Compare-and-set
- Conflict resolution and replication

Very practical information that helps every developer.

### Safety and liveness

*Where:* Page 308, Chapter 8: The Trouble with Distributed-Systems

I learned that there are two important kinds of properties for correctness of distributed algorithms; safety and liveness. These two kinds can help us to deal with difficult system models.
Typically in distributed systems you want the safety properties to always hold--even if all nodes crash for example. Liveness properties can be more flexible.

#### Safety

This property can be informally defined as *nothing bad happens*, the more precise definitions is:

> If a safety property is violated, we can point at a particular point in time at which it was broken (...). After a safety property has been violated, the violation cannot be undone -- the damage is already done.

#### Liveness

> A liveness property works the other way round: it may not hold at some point in time (for example, a node may have sent a request but not yet received a response), but there is always hope that it may be satisfied in the future (namely by receiving a response).

### Linearizability is stronger than casual consistency

*Where:* Page 342, Chapter 9: Consistency and Consensus

This is a section I want to re-read to make sure I understand it completely. I've tried
to immerse myself more into the distributed systems world and all the interesting and sometimes mind bending problems. So much research go through and so much head scratching.

What caught my eye in this section is this passage:

> In fact, causal consistency is the strongest possible consistency model that does not slow down due to network delays, and remains available in the face of network failures.

> In many cases, systems that appear to require linearizability in fact only require causal consistency, which can be implemented more efficiently.

Apparently this is kind of recent research, and we may still see cool things be implemented based on this!

### Chapter 9 Summary

*Where:* Page 373, Chapter 9: Consistency and Consensus

Not going to include everything, but I liked this summary as a sort of reference on some common terms and their meanings in distributed systems.

- Linearizability: Popular consistency model. Goal is to make replicated data appear as though there is only a single copy. All operations act on the single copy atomically. Appealing because it's easy to understand. Downside of being slow. Especially in environments with large network delays (cloud).
- Causality: Imposes an ordering on events in a system. Weaker consistency model than linearizability. Some things can be concurrent. Does not incur coordination overhead like linearizability, also less sensitive to network delays.
- Consensus: All nodes agree on the decision. Many problems can be reduced to the consensus problem; Linearizable compare-and-set registers, Atomic transaction commit, Total order broadcast, Locks and leases, Membership/coordination service, Uniqueness constraint. Straightforward on single node, or single node decision maker.

### Using logs for message storage

*Where:* Page 447, Chapter 11: Stream Processing

A very good breakdown how using a log can be used to power a message broker (like Kafka or Kinesis).
Both in the simplest way with a single node, and how it can be partitioned across
machines.

I think it would be a really fun experiment to try and build a simple message broker like this myself.

### Designing for auditability

*Where:* Page 531, Chapter 12: The Future of Data Systems

I enjoyed this whole chapter a lot, and some of the concerns Kleppmann bring up really resonate with me.

One thing that may become more important in the close future is how auditable our systems are.
If you mutate a table in a relational database, the previous state is lost and there might
not be a trace of why something was changed. This can be a huge problem.

Event-based systems have an advantage here if the event is kept around (event sourcing). We need to design systems that
are deterministic, repeatable and explicit around data flow. Immutable events can allow us
to do time travel debugging.

### Feedback loops

*Where:* Page 536, Chapter 12: The Future of Data Systems

This section is about (bad) feedback loops in recommendation systems and other such predictive applications.

We've all heard about social media echo chambers or filter bubbles. Recommendation systems
can be a huge contributing factor to this phenomenon.

Another example is if an employer use credit-scores to evaluate potential hires.
If you miss a payments on bills (due to some catastrophic event beyond your control), your credit-score suffer which in turn makes it harder for you to get a job and get back on track.

Difficult problems that must be tackled head on; more and more ML is powering important
parts of all of our lives with increasing adoption rates. Scary stuff even if built with good intentions.

### Data as assets and power

*Where:* Page 540, Chapter 12: The Future of Data Systems

I can't even count how many scandals about the misuse of user data that has been reported on
in 2018. It seems to be prevalent and have left me very skeptical and paranoid of all online services.

In this section Kleppmann argues that we should perhaps view data not as an asset like any other, but more like a hazardous one. We need to safe guard it against current abuse and also make sure it does not fall into the wrong hands.

> When collecting data, we need to consider not just today's political environment, but all possible future governments. There is no guarantee that every government elected in the future will respect human rights and civil liberties, so "it is poor civic hygiene to install technologies that could someday facilitate a police state"

## In conclusion

Read the book. Learn about how databases work. Learn the underlying ideas of the technology you might already be using and what you can expect from it. Get better at deciding on what technology to use and when. The choices you make will have very real impact on the development and operation of your systems.

Think about your system holistically: correctness, behaviour in face of network partitions, observability, traceability, auditability. Think about how the system affects users and non-users.
Think about data as a potentially hazardous asset.

This is a book I recommend all developers read.
