---
%{
  title: "Continously deploying a docker aware phoenix app",
  description: "A recipe for doing Continous Deployment of a phoenix app running in Docker Swarm",
  created_at: "2020-05-08T17:05:26.501564Z"
}
---

One of the things I knew I wanted for [Playlistlog](/posts/2020-04-05-playlistlog.html) was to do Continous Delivery on pushes to the master branch. This is a workflow I enjoy a lot, and contributes to a healthier development cycle. When using [Gigalixir](https://gigalixir.com/) (for [Lasso](https://lasso.gigalixirapp.com/)) CD came for free. At work I have previously used Mesos+Marathon, AWS Elastic Beanstalk, and Kubernetes to set up different CD workflows. Since Playlistlog is hosted on a Digital Ocean droplet I don't have anything pre-made set up. In this post I'll describe in detail how to do CD without too many dependencies.

## The building blocks

There's a bunch of key elements needed to make this CD thing happen. Here's what I have to work with.

### Web app

I have a web app, running inside a docker container. The application receives and handles HTTP requests. It happens to be an Elixir [phoenix](https://phoenixframework.org/) app, but that is not important except for making sense of the code samples in this post.

### Docker container

The docker container is hosted on dockerhub. It gets built and pushed by a github action on master commits.
That it is specifically dockerhub is not important either. The most important part is that you have a way to know when a new version/tag
is available. For example by setting up a [webhook](https://docs.docker.com/docker-hub/webhooks/).

I could of course also have opted to not do docker at all. In the end I decided to go with it since I want as few dependencies on my server as possible.

### Container orchestrator

The docker container runs as a [Docker Swarm Service](https://docs.docker.com/engine/swarm/). My swarm setup is dead simple, only one *service*. So why do I need it? To do rolling updates (ie when updating to a newer version of the application) with no downtime.

My first, manual deployment/upgrade script was basically this: `docker service update --update-order start-first --image vorce/playlistlog:$tag playlistlog`. Where `$tag` is the new version of the docker image that I wanted to run. I executed this manually whenever a new docker image was uploaded to dockerhub.

I thought about doing zero downtime deploys with some nginx and shell script voodoo for a second. But decided against it since swarm comes with docker which I wanted anyway.

### Server

I have a publically available place to run the docker container, a Digital Ocean droplet to be precise. But this could also be a Raspberry PI or whatever. The point is that there is nothing that gives me CD out of the box.

On the server I am running stock Ubuntu 18. I have installed nginx, certbot (for the let's encrypt cert), and docker. That's it, and I am very hesitant to install more stuff.

## The sauce

Before embarking on continously deploying I made sure that I could manually deploy. And that the app was running and everything was stable.

Okay so with all the pre-reqs out of the way, there's only two things we need to do to get the juicy CD workflow:

1. We need a way to handle the webhook request from dockerhub. This request will contain the new tag to upgrade to.
2. When we have the new tag, we need to call `docker service update` with the new image details.

Sounds very easy.

### Handling the webhook request

To handle the request we need a HTTP server and... something to parse the json, pick out the tag, and then trigger the second step.

There are a bunch of available software that's made to do exactly this. The problem I encountered while looking at some of those apps is that none of them are Invented Here. Nah just kidding. The problem is that they are all quite generic, so you have to learn how to configure, deploy, test, and operate them. And some of them require runtimes (like Python 2, or Ruby), which I do not want to install. I was seriously considering writing my first golang program to do the job. In a super tailored, specific and minimal way (I don't need to handle any webhook, just the one from dockerhub). But again, it would require a HTTP server, a new entry in my nginx config etc.

I already have a HTTP server! And an app that handles incoming HTTP requests - my own webapp. Why not add a route for the webhook request there?
Well we are then coupling the app to dockerhub which doesn't make a lot of sense. I decided that in this case it seems worth it.

On to the next problem then. How can I communicate to the outside host and tell it to update when the webhook handler is running inside docker?

### Talking to docker inside docker

My first idea was to run a shell script from my phoenix app, but I realized that there is such a thing as a Docker API.

To use the Docker API you can send request to the docker unix socket. That's cool. I've not really worked with unix sockets before like that. After some searching I could list services on the host (not inside docker yet) by running: `curl -XGET --unix-socket /var/run/docker.sock http://localhost/services`.
Nice.

Let's see what happens if I do this inside my app's container.

```bash
me@ubuntu-host:~$ docker exec -ti <containerId> sh
/app $ curl -XGET --unix-socket /var/run/docker.sock http://localhost/services
sh: curl: not found
```

Haha oh right, we don't have curl in this minimal container. No probs am I right.

```bash
/app $ apk add curl
ERROR: Unable to lock database: Permission denied
ERROR: Failed to open apk database: Permission denied
/app $ sudo apk add curl
sh: sudo: not found
/app $ su root
su: must be suid to work properly
```

Ok ok, not running as root and no root available (*security*). Cool, cool, cool. I could of course change that but figured we could try some other stuff.

```bash
me@ubuntu-host:~$ docker run -ti alpine:latest sh
/ # apk add curl
...
/ # curl -XGET --unix-socket /var/run/docker.sock http://localhost/services
curl: (7) Couldn't connect to server
/ # ls -al /var/run/docker.sock
ls: /var/run/docker.sock: No such file or directory
```

I knew that. Ahem. Can I mount it in to the image from the host?

```bash
me@ubuntu-host:~$ docker run -ti -v /var/run/docker.sock:/var/run/docker.sock alpine:latest sh
/ # apk add curl
/ # curl -XGET --unix-socket /var/run/docker.sock http://localhost/services
[{"ID":"a41ku9ne..", ...moar json..}]
```

Holy crap yes!

#### Permissions

After mounting in the docker socket into my app's container I hit the next issue. The user in the container doesn't have read/write permission to `/var/run/docker.sock`, nor root access.

This took a while to get around, and I am not too pleased with the "fix" since it's brittle.
I ended up adding the user running the app to the group that owns docker.sock on the host in my [Dockerfile](https://github.com/vorce/playlist_log/blob/master/Dockerfile#L49) -- eeew.

If I want to run the container on a different host I would most likely need to change that :/

Anyone has a better way? Please get in touch (create an [issue on playlistlog](https://github.com/vorce/playlist_log/issues) or something).

#### Get service Id and Version

Ok so the infrastructure is in place. We can communicate with the Docker API from our app. To update a swarm service you need some information that we first have to get (see the [API docs](https://docs.docker.com/engine/api/v1.40/#operation/ServiceDelete)). We will need the swarm service id, and its version.

To get the service details I request all running services from the Docker API and then pick out the service with the correct name.

```elixir
@docker_socket "/var/run/docker.sock"
@socket_path URI.encode_www_form(@docker_socket)
@protocol "http+unix://"
@base_url @protocol <> @socket_path

@doc """
Gets the service details for playlistlog
Docker API: https://docs.docker.com/engine/api/v1.40/#operation/ServiceList
"""
def get_service_details() do
  url = @base_url <> "/services"

  with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get(url),
        {:ok, services} <- Jason.decode(body) do
    find_service_details(services)
  else
    unexpected -> {:error, :get_service_details, unexpected}
  end
end

def find_service_details(services) do
  Enum.find_value(services, {:error, :no_playlistlog_service}, fn service ->
    if get_in(service, ["Spec", "Name"]) == "playlistlog" do
      {:ok, service}
    end
  end)
end
```

#### Post the service update

We're getting close. Now all that's left is to create the payload for the update service request and post it.
An important detail that's not clear from the documentation is that the payload must be complete. IE all fields should be present not only the ones we want to update.

Good thing that we have the full service details from the `get_service_details/1` call.

```elixir
@doc """
Update a service
POST /services/(id)/update
Docker API docs: https://docs.docker.com/engine/api/v1.40/#operation/ServiceUpdate
"""
def update_service(service, tag, base_url \\ @base_url) do
  id = Map.get(service, "ID")
  version = get_in(service, ["Version", "Index"])
  url = base_url <> "/services/#{id}/update?version=#{version}"
  headers = ["content-type": "application/json"]
  payload = update_payload(service, tag)
  details = [url: url, id: id, version: version, tag: tag, payload: filtered(payload)]

  case HTTPoison.post(url, Jason.encode!(payload), headers) do
    {:ok, %HTTPoison.Response{status_code: 200}} ->
      Logger.info("Successfully updated service, details: #{inspect(details)}")

    unexpected ->
      {:error, :update_service, unexpected}
  end
end

defp update_payload(service, tag) do
  service_spec = Map.fetch!(service, "Spec")

  put_in(
    service_spec,
    ["TaskTemplate", "ContainerSpec", "Image"],
    "vorce/playlistlog:#{tag}"
  )
end

# Remove env variables and their values (since they may contain secrets)
defp filtered(payload) do
  put_in(payload, ["TaskTemplate", "ContainerSpec", "Env"], ["***filtered***"])
end
```

### Other ideas

I went through a couple of different ideas before settling on the implementation I have now.

[Nomad](https://www.nomadproject.io/), [traefik](https://containo.us/traefik/), [k8s](https://kubernetes.io/) were all on the table at one point or another. The [github issue for setting up CD](https://github.com/vorce/playlist_log/issues/7) served as a brain dump and log.

Would it have been simpler to set up Continuous Deployment with something else? Maybe, but then again you would need another dependency.

## Show me the code

Another convenient benefit of this approach that most of the workflow is documented in a sort of logical place. In the application code itself. Here's how it's implemented for Playlistlog: [controller](https://github.com/vorce/playlist_log/blob/master/lib/playlist_log_web/controllers/dockerhub_controller.ex) + [logic](https://github.com/vorce/playlist_log/blob/master/lib/playlist_log/dockerhub.ex).

## Conclusion

I'm happy with this setup. It's pragmatic, works well, and does not make me reliant on a particular server setup. As long as I have docker and access to the docker socket (this might not be common though?) I should be able to run this setup anywhere.

I would love to hear suggestions for improvements or alternative ways -- my contact details are on the [about page](/about.html).
