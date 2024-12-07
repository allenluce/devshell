# Prepare the main image
FROM alpine:3.21

# Install various useful packages
RUN apk add --no-cache --update dumb-init git curl bash zsh emacs-nox \
  ripgrep openssh sudo go tcpdump strace tmux ca-certificates \
  util-linux binutils findutils oci-cli && \
  rm -rf /var/cache/apk/* && :

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod a+x kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# Add local user (and grant it sudo access)
ARG USER
RUN adduser -G wheel -s /bin/zsh -D ${USER}
RUN echo "${USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && chmod 0440 /etc/sudoers.d/${USER}

# Install user's local stuff
WORKDIR /home/${USER}

# Generate host keys for sshd
RUN ssh-keygen -A

USER ${USER}

# SSH auth stuff
ARG AUTHORIZED_KEYS
RUN mkdir -m 700 .ssh
RUN echo ${AUTHORIZED_KEYS} | base64 -d > .ssh/authorized_keys
RUN chmod 600 .ssh/authorized_keys

# Install prezto (https://github.com/sorin-ionescu/prezto)
COPY --chown=${USER} .zprezto/ .zprezto/
COPY --chown=${USER} .p10k.zsh .p10k.zsh
RUN for rcfile in $(ls -d .zprezto/runcoms/* | grep -v README.md); do ln -s $rcfile .${rcfile##*/}; done

# Install Emacs Prelude
RUN curl -L https://git.io/epre | sh
RUN emacs --daemon # Compile it.

# Start SSHD and sleep for 10 years

ENTRYPOINT ["/usr/bin/dumb-init", "zsh", "-c", "sudo /usr/sbin/sshd && exec $*", "--"]
CMD ["/bin/sleep", "3650d"]
