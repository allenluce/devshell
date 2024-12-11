# A Kubernetes utility pod for developers

This pod provides an environment that resembles the running
environment of the average ([Oracle Linux
8](https://docs.oracle.com/en/operating-systems/oracle-linux/8/)-based)
Kubernetes pod.  It can be used when to track down errors that evade
reproduction in a local (non-cluster) development environment.

It includes several handy tools:

- Emacs (with [Prelude](https://github.com/bbatsov/prelude))
- ZSH (with [Prezto](https://github.com/sorin-ionescu/prezto))
- [Ripgrep](https://github.com/BurntSushi/ripgrep)
- Git, cURL, OpenSSH, sudo, tcpdump, strace, tmux, mlocate, man pages, etc.

As well as a custom-tailored .zshrc based on
[Powerlevel10k](https://github.com/romkatv/powerlevel10k).

# Running in Kubernetes

A yaml file is provided that contains a definition suitable for most
k8s clusters.

## Starting a debug pod in Kubernetes

It's recommended to start it as a debug pod. This gives it the ability
to see and manage node processes and the node's filename (via
`/host`). You can start one persistent debug pod per node with:

    for node_name in $(kubectl get nodes -o name); do
      kubectl debug ${node_name} --image=allenluce/oci-shell
    done

## Viewing the list of running debuggers

    kubectl get pod -o jsonpath='{range .items[?(@.spec.containers[*].image=="allenluce/oci-shell")]}{.metadata.name}{"\n"}{end}' --field-selector=status.phase=Running

## Attaching to a running debug pod

    POD_NAME=$(kubectl get pod -o jsonpath='{range .items[?(@.spec.containers[*].image=="allenluce/oci-shell")]}{.metadata.name}{"\n"}{end}' --field-selector=status.phase=Running | head -1)
    kubectl exec -it $POD_NAME -- zsh

## Shutting down and removing the pod

    kubectl delete pod $POD_NAME

# Using locally in Docker

## Start up a persistent container

    docker run --rm -d -h oci-shell --name oci-shell allenluce/oci-shell

## Attach to the running container

    docker exec --privileged --detach-keys="ctrl-o,ctrl-o" -it oci-shell zsh

By default, the container's non-root user's name is "allen." You can
set your own username by creating a new Docker image. See the
instructions below.

## Kill the container

    docker kill oci-shell

The image will clean itself up because of the --rm supplied above.

## One-time quick shell

Alternatively, start and attach in a single command (the container
will exit when the shell exits):

    docker run --privileged -it --rm allenluce/oci-shell zsh

# Creating a new Docker image

You can set your own username and load the image into your own Docker
Hub repo. Replace "allen" with your username and "allenluce" with your
Docker Hub login in the following commands.

## Building the image

Choose a username for yourself (I'm using `allen` here). Your existing
`~/.ssh/authorized_keys` file is passed to seed the `authorized_keys`
file for the new user in the container.

    docker buildx build --build-arg AUTH_KEYS="$(base64 -i ~/.ssh/authorized_keys)" --build-arg USER=allen -t allenluce/oci-shell .

## Pushing the newly built image to Docker hub

    docker push allenluce/oci-shell

