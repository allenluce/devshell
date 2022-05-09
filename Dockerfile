FROM alpine:3.15

ARG USER

# Install dumb-init
RUN \
  apk add --no-cache --update python3 python3-dev py-pip build-base && \
  pip install dumb-init && \
  apk del python3 python3-dev py-pip build-base && \
  rm -rf /var/cache/apk/* && :

# Install various packages
RUN apk add --no-cache git curl zsh emacs-nox ripgrep zerotier-one openssh sudo go tcpdump strace
RUN sudo sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers
RUN adduser -G wheel -s /bin/zsh -D ${USER}
RUN passwd -u ${USER}

# Install stuff for the user
WORKDIR /home/${USER}

# SSH auth stuff
RUN mkdir .ssh && chown ${USER} .ssh
COPY --chown=${USER} .ssh .ssh
RUN chmod 700 .ssh && chmod 600 .ssh/*
RUN ssh-keygen -A

# NVM dependencies
RUN apk add -U curl bash ca-certificates openssl ncurses coreutils python2 make gcc g++ libgcc linux-headers grep util-linux binutils findutils

USER ${USER}

# Set up Oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
COPY --chown=${USER} .zshrc.standard .zshrc
COPY --chown=${USER} .oh-my-zsh/themes/bullet-train.zsh-theme .oh-my-zsh/themes

# Install NVM
RUN sudo apk add --no-cache libstdc++; \
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.1/install.sh | bash; \
  echo 'source $HOME/.profile;' >> $HOME/.zshrc; \
  echo 'export NVM_NODEJS_ORG_MIRROR=https://unofficial-builds.nodejs.org/download/release;' >> $HOME/.profile; \
  echo 'nvm_get_arch() { nvm_echo "x64-musl"; }' >> $HOME/.profile; \
  NVM_DIR="$HOME/.nvm"; source $HOME/.nvm/nvm.sh; source $HOME/.profile; \
  nvm install node

# Install Emacs Prelude
RUN curl -L https://git.io/epre | sh
RUN emacs --daemon # Compile it.

# Start Zerotier, SSHD, and sleep for 10 years.

ENTRYPOINT ["/usr/bin/dumb-init", "zsh", "-c", "sudo zerotier-one -d && sudo /usr/sbin/sshd && exec $*", "--"]
CMD ["/bin/sleep", "3650d"]
