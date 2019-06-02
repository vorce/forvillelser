---
%{
  title: "Lasso - a Phoenix LiveView app running on Gigalixir",
  description: "How I built Lasso, my first phoenix liveview app",
  created_at: "2019-05-17T16:51:36.428007Z"
}
---
In this post I'll outline how I built [Lasso](http://lasso.gigalixirapp.com/), my first Phoenix Liveview app and how I deployed it to Gigalixir. The [Lasso code](https://github.com/vorce/lasso) is available on github.

I've been meaning to play with [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) since the moment it came out. A year or so ago I wanted to build something similar to [webhookinbox](http://webhookinbox.com/) - which I find quite handy. But I never got started on it. However I had three hours to kill on the train to Code BEAM STO and figured this could be something suitable for trying LiveView on.

The idea is to have a web page where you can see HTTP requests to a  certain URL. The spicy part would be to be able to see those request as they come in -- live.

### Generate project and add dependencies

Nothing exciting here. Standard phoenix project, without ecto since I don't want a database for this: `mix phx.new --no-ecto lasso`

After that I followed the instructions for adding LiveView from its [README](https://github.com/phoenixframework/phoenix_live_view#installation).

### Main pieces

I quickly realize I needed a couple of different components:

1. A way to create a new, unique URL destination (that expires) which can accept HTTP requests
2. A page that you can share to view those requests as they come in
3. Some sort of state of historic requests per destination (sliding window of some size)

### Creating the destinations

I knew I didn't want the destination URLs to be guessable, and they needed to be unique. So I made each url contain a generated uuid. To keep track of the existing destinations the uuid is added to a an in memory [cache](https://github.com/sasa1977/con_cache) with a TTL of 24 hours.

When a request is made to the destination we first check that it actually exists in the cache, and if so proceed to handle it, if not the client will get a 404.

An example destination URL would be `http://localhost:4000/hooks/3c72c523-9f8c-4ae9-98c9-faa878d12f58`

### Visualizing the requests

Here's where LiveView gets into the picture. To view the
requests we need a page connected to the destination, the uuid is perfect for that. The visualization URL for the example destination would be `http://localhost:4000/lasso/3c72c523-9f8c-4ae9-98c9-faa878d12f58`. Here once again we need to check that the uuid is in the cache before serving the page. To serve the page we will finally need to create a LiveView.

Most of the examples I've seen of LiveView has the template inlined in code with a sigil. I wanted to use a separate file for it so the first thing I did was to create a `.leex` file and put some text with a link to the destination URL in it. This works just like a normal `.eex` template so far, nothing live about it yet.

#### Live updates

I had no idea how to actually "trigger" the update. Most examples I found used some element on the page that was served (using `phx-click`) to trigger updates. I needed something entirely decoupled from the page to be the trigger (specifically the request to the destination URL).

Luckily I found something interesting in the [phoenix_live_view_example](https://github.com/chrismccord/phoenix_live_view_example) repo. In the CRUD demo whenever a user is created/updated/deleted a liveview will know about it.
To accomplish that the [demo](https://github.com/chrismccord/phoenix_live_view_example/blob/master/lib/demo/accounts/accounts.ex#L66) uses Phoenix.PubSub.

I had never used [Phoenix PubSub](https://github.com/phoenixframework/phoenix_pubsub) before so got pretty excited in trying that out as well. At the same time it seems a bit overkill since I will only run Lasso on one machine (to start with).
I decided to try it out anyway.

When mounting the LiveView for the destination we start subscribing to the pubsub topic, again using the uuid for the destination as key. Then whenever we handle a request for a destination we push
request details to the pubsub topic. Since the LiveView view is a process itself it can then `handle_info` and pattern match on the type of messages we expect from the topic, and finally push the update to the socket.

### History

Now we can see updates on the page! That's very cool. To make the project more useful you might want to be able to share the view URL and let others see the same thing, including any requests that came in before they opened the page. To accomplish that we have to store some state of previous requests.

Luckily we have the cache where the uuid is stored, with a very small change we can associate it with a list of requests.
And every time a destination URL is hit we append to that list.
I decided to limit the history to the last 100 requests.

After this feature was added I spent quite some time on trying to make the presentation of each request make sense and look at least half decent. Not qutie sure I succeeded :)

### Deployment

I've tried various services for deploying and running apps. Bare metal, Mesos/Marathon, Heroku, AWS Elasticbeanstalk, Kubernetes. Each comes with its pros and cons. For personal projects my requirements are usually: Low cost and low effort.

Heroku free tier tends to wins on both of those fronts. This time I needed something that would not lose its in-memory contents too frequently though (heroku free tier apps are restarted now and then).

[Gigalixir's](https://gigalixir.com/) free tier promises fewer constraints for my app, so I decided to give that service a spin.

Following the Gigalixir guide on phoenix apps made the setup and deploy completely pain free - it just worked on the first attempt.
Adding SSL was also smooth. If you are building an elixir app and want somewhere simple and cheap to run it definetly give Gigalixir a try!

### Recap

- Phoenix LiveView is very cool and super useful for adding some interactive elements to your elixir phoenix app.
- Gigalixir is impressively easy to use and its free tier quite capable
- Train rides are the best (I wrote this blog post on the way back from [Code BEAM STO](codesync.global/conferences/code-beam-sto-2019/))
