---
%{
  title: "Continously deploying a docker aware phoenix app",
  description: "A recipe for doing Continous Deployment of a phoenix app running in Docker Swarm",
  created_at: "2020-04-14T18:18:26.501564Z"
}
---

One of the things I knew I really wanted for [Playlistlog](/posts/2020-04-05-playlistlog.html) was to do Continous Delivery on pushes to the master branch. This is a workflow I enjoy a lot, and I think contributes to a healthier development cycle. When using [Gigalixir](https://gigalixir.com/) (for [Lasso](https://lasso.gigalixirapp.com/)) CD came for free. At work I have previously used Mesos+Marathon, AWS Elastic Beanstalk, and Kubernetes to set up different CD workflows. Since Playlistlog is hosted on a Digital Ocean droplet I don't have anything pre-made set up. In this post I'll describe in detail how to do CD without too many dependencies.

## The building blocks

There's a bunch of key elements needed to make this CD thing happen. Here's what I have to work with.

### Web app

I have a web app, running inside a docker container. The application receives and handles http requests.

### Docker container

The docker container is hosted on dockerhub. It gets built and pushed by a github action on master commits.
That it is specifically dockerhub is not the most important part. The most important part is that you have a way to know when a new version/tag
is available. For example by setting up a [webhook](https://docs.docker.com/docker-hub/webhooks/).

I could also have opted to not do docker at all, but decided to go with it since I want as few dependencies on my server as possible.

### Container orchestrator

The docker container runs as a [Docker Swarm Service](https://docs.docker.com/engine/swarm/). My swarm setup is dead simple, only one *service*. So why do I need it? To do rolling updates (ie when updating to a newer version of the application) with no downtime.

My first, manual deployment/upgrade script was basically this: `docker service update --update-order start-first --image vorce/playlistlog:$tag playlistlog` where `$tag` is the new version of the docker image that I wanted to run. I executed this manually after a new docker image was uploaded to dockerhub.

I thought about doing zero downtime deploys with some nginx and shell script voodoo, but decided against it since swarm is just there after installing docker (which I wanted anyway).

### Server

I have a publically available place to run the docker container, a Digital Ocean droplet to be precise. But this could also be a Raspberry PI or whatever. The point is that there is nothing that just gives me CD out of the box.

On the server I am running stock Ubuntu 18. I have installed nginx, certbot (for the let's encrypt cert), and docker. That's it, and I am very hesitant to install more stuff.

## The sauce

Obviously before embarking on continously deploying I made sure that I could manually deploy, the app was running and everything was stable.

Okay so with all the pre-reqs out of the way, there's only two things we need to do to get the juicy CD workflow:

1. We need a way to handle the webhook request from dockerhub. This request will contain the new tag to upgrade to.
2. When we have the new tag, we need to call `docker service update` with the new image details.

Sounds very easy.

### Handling the webhook request

To do this we obviously need a http server and... an app to parse the json, pick out the tag, and then trigger the second step.

There are a bunch of readily available software that is specifically made to be able to do this. The problem I encountered while looking at some of those apps is that none of them were Invented Here. No just kidding, the problem is that they are all quite generic, so you have to learn how to configure, deploy, test, and operate them. And some of them require runtimes (like Python 2, or Ruby), which I do not want to install. I was heavily considering writing my first golang program, that would do the job in a super tailored, specific and minimal way (I don't need to handle any webhook, just the one from dockerhub). But again, it would require a http server, a new entry in my nginx config etc.

I already have a http server! And an app that handles incoming http requests - my own webapp. Why not add a route for the webhook request there?
Well we are then coupling the app to dockerhub which doesn't make a lot of sense. I decided that in this case it's probably worth it.

On to the next problem then, if the webhook handler is running inside a docker container how can I communicate to the outside host and tell swarm to update?

### Talking to docker inside docker

My first idea was to run a shell script from my phoenix app, but quickly realized that there is such a thing as a Docker API.

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

I knew that. Ahem. Can I..?

```bash
me@ubuntu-host:~$ docker run -ti -v /var/run/docker.sock:/var/run/docker.sock alpine:latest sh
/ # apk add curl
/ # curl -XGET --unix-socket /var/run/docker.sock http://localhost/services
[{"ID":"a41ku9ne..", ...moar json..}]
```

Holy crap yes. So mounting in the docker socket from the host works.

TBD: Permissions
TBD: Get service Id and Version
TBD: Post update

### Different ideas

I went through a couple of different ideas before settling on the implementation I have now.

Nomad, traefik, k8s, ...

## App code

TBD

## References

https://medium.com/@iaincollins/docker-swarm-automated-deployment-cb477767dfcf

