---
%{
  title: "Finding bugs with property based testing",
  description: "Using property based tests to battle edge cases",
  created_at: "2018-10-29T15:20:37.240642Z"
}
---
Property based testing has been on my radar ever since being force to write QuickCheck tests for the introduction to functional programming course at Chalmers university some 10+ years ago.

However examples based tests has always felt more intuitive, and maybe more importantly has been the go to approach to development in the places I've worked.

Recently I've tried to force myself into the invariant based reasoning mode, and apply
property based testing. This was prompted by some interesting
issues around testing inputs consisting of date times and time zones.
Edge cases lead to head scratching bugs despite good unit test coverage.

I still haven't gotten to the stage where I can get property based tests to drive design of the implementation. But I've gotten much more comfortable at wielding this amazing tool.

### Strengths

#### Edge cases

This probably doesn't come as a surprise. Generating inputs instead of selecting them yourself yields impressive coverage and can catch the most subtle cases.

#### Algorithms and data-structures

Property based tests seems like the perfect fit for these type of functions. Maybe it's because there is usually quite clear desired properties in this space.

I was happy and impressed by how fast property based tests [found bugs](https://github.com/vorce/dasie/pull/8) in my own (persistent) data structure implementations.

#### Large combination of inputs

More generally, it's getting apparent to me that anything where there the combined input set is very large property bases tests might be a good fit.

### Conclusion

I think there are way more opportunities to improve confidence in any code base with property based tests, than what we usually think.

I'm also convinced that having this reasoning mode -- "what needs to go right?" -- in your arsenal might make some hairy issues a bit easier to work with.
