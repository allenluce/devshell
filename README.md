# A Kubernetes development pod

This pod provides an environment that closely resembles the running
environment of the average (i.e. Alpine Linux based) Kubernetes pod.
It can be used when to track down errors that evade reproduction in a
local (non-cluster) development environment.

It includes an Emacs-based development environment and several handy tools:
A handy Docker image for running a usable interactive terminal-based
development envrionment on Kubernetes clusters. Includes tools I find
handy for development:

- NodeJS (with [NVM](https://github.com/nvm-sh/nvm))
- Go
- Emacs (with [Prelude](https://github.com/bbatsov/prelude))
- ZSH (with [Oh My Zsh](https://ohmyz.sh/))
- [Ripgrep](https://github.com/BurntSushi/ripgrep)
- [ZeroTier](https://zerotier.com/)
- Git, cURL, OpenSSH, sudo, tcpdump, strace, tmux

And adds a custom-tailored .zshrc based on the [Bullet Train](https://github.com/caiogondim/bullet-train.zsh) theme.

# Using via Docker

## Start up in the background

    docker run --rm -d -h shell --name shell allenluce/shell

## Attach to the running container

    docker exec --privileged --detach-keys="ctrl-o,ctrl-o" -it shell zsh

By default, the container's non-root user's name is "allen." You can
set your own username by creating a new Docker image. See the
instructions below.

## Kill the container

    docker kill shell

The image will clean itself up because of the --rm supplied above.

## Quick one-off shell

Alternatively, start and attach in a single command (the container
will exit when the shell exits):

    docker run --privileged -it --rm allenluce/shell zsh

# Creating a new Docker image

You can set your own username and load the image into your own Docker
Hub repo. Replace "allen" with your username and "allenluce" with your
Docker Hub login in the following commands.

## Building the image

Choose a username for yourself (I'm using `allen` here). Your existing
`~/.ssh/authorized_keys` file is passed to seed the `authorized_keys`
file for the new user in the container.

    docker build --build-arg AUTH_KEYS="$(base64 ~/.ssh/authorized_keys)" --build-arg USER=allen -t allenluce/shell .

## Pushing the newly built image to Docker hub

    docker push allenluce/shell

# Running in Kubernetes

A yaml file is provided that contains a definition suitable for most
k8s clusters.

# Starting the container in Kubernetes

    apply -f shell.yml

# Attaching to the running pod

    kubectl exec -it shell -- zsh

# Shutting down and removing the pod

    kubectl delete pod shell

# ZeroTier networking

To join a network:

    sudo zerotier-cli join <NETWORK-ID>

# IPv6

IPV6 may not work on the container by default. To get it going, try this:

    sysctl net.ipv6.conf.all.disable_ipv6=0

If you do this after joining a network, you may have to leave and
rejoin the network in order for the interface to get an address:

    sudo zerotier-cli leave <NETWORK-ID>
    sudo zerotier-cli join <NETWORK-ID>

Note that the container runs in a privileged security context in order
to allow ZeroTier access to the TAP/TUN device.

# SSH keys

A set of SSH public keys (my personal ones) are located in
`.ssh/authorized_keys`. If you want to be able to SSH into your pod
(either via ZeroTier or pod networking), be sure to add your own keys
to that file.
