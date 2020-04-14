---
%{
  title: "Continously deploying a docker aware phoenix app",
  description: "A recipe for doing Continous Deployment of a phoenix app running in Docker Swarm",
  created_at: "2020-04-14T18:18:26.501564Z"
}
---

One of the things I knew I really wanted for [Playlistlog](/posts/2020-04-05-playlistlog.html) was to do Continous Delivery on pushes to the master branch. This is a workflow I enjoy a lot, and I think contributes to a healthier development cycle. When using [Gigalixir](https://gigalixir.com/) (for [Lasso](https://lasso.gigalixirapp.com/)) CD came for free. At work I have previously used Mesos+Marathon, AWS Elastic Beanstalk, and Kubernetes to set up CD workflows. Since Playlistlog is hosted on a Digital Ocean droplet I don't have anything ready made.

## Enter the Swarm

Playlistlog is a [Phoenix](https://www.phoenixframework.org/) application running in a docker container orchestrated by [Docker Swarm](https://docs.docker.com/engine/swarm/). The swarm setup is dead simple, only one *service*. So why do I need it? To do rolling updates (ie when updating to a newer version of the application) with no downtime.

My first, manual deployment/upgrade script was basically this: `docker service update --update-order start-first --image vorce/playlistlog:$tag playlistlog` where `$tag` is the new version of the docker image that I wanted to run. I executed this after a new docker image was uploaded to dockerhub.

Dockhub also supports [webhooks](https://docs.docker.com/docker-hub/webhooks/). Can I use that to auto update my app?

## Webhook

Of course I can! The real interesting question is *how* though. But before we get to that, here's what I want to achieve.

1. Accept http POST requests from dockerhub, and verify that it is coming from the right source.
2. Pick out the new tag from the payload, and use that to update my service.

To accomplish #2 there are of course a bunch of existing software that I can use. To me they were all too general, meaning you have to
work out how to configure them properly, deploy to my droplet, and test. Also I want to keep the required software on my server to the minimum, so that I can easily switch to a different one. Right now all I have installed in addition to the default stuff is nginx, certbot, and docker.

...
