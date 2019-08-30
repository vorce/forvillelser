---
%{
  title: "Jerry - a silly macos automatic mouse move & click toy",
  description: "How to use macos' API for moving the mouse",
  created_at: "2019-08-30T13:05:21.047668Z",
  categories: [:macos, :gist, :swift]
}
---

Recently I wanted to look into how to move the mouse around in macos. The end result of my research and experimenting is "Jerry" -- a little Swift playground snippet I've put up as a [**gist**](https://gist.github.com/vorce/04e660526473beecdc3029cf7c5a761c). When you run Jerry it makes your mouse move around and (left) click at each point. The movement uses easing to make it a little more human-like.

While reading up on the API calls, and refreshing my shallow [Swift](https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html) knowledge I stumbled upon the amazing [cliclick](https://github.com/BlueM/cliclick) tool. That's where I got the easing code from. To move the mouse around and click I could most likely just have used cliclick instead of writing something myself. But it was fun to brush up on Swift and explore the macos mouse API.

<script src="https://gist.github.com/vorce/04e660526473beecdc3029cf7c5a761c.js"></script>
