# Prepare aws-cli
FROM python:3.9.12-alpine3.15 as aws-cli-builder
ENV AWS_CLI_VERSION=2.6.3

RUN set -ex; \
    apk add --no-cache \
    git unzip groff \
    build-base libffi-dev cmake

RUN set -eux; \
    mkdir /aws; \
    git clone --single-branch --depth 1 -b ${AWS_CLI_VERSION} https://github.com/aws/aws-cli.git /aws; \
    cd /aws; \
    sed -i'' 's/PyInstaller.*/PyInstaller==4.10/g' requirements-build.txt; \
    python -m venv venv; \
    . venv/bin/activate; \
    ./scripts/installers/make-exe

RUN set -ex; \
    unzip /aws/dist/awscli-exe.zip; \
    ./aws/install --bin-dir /aws-cli-bin; \
    /aws-cli-bin/aws --version

# Prepare the main image
FROM alpine:3.15

# Install aws-cli from the builder
COPY --from=aws-cli-builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=aws-cli-builder /aws-cli-bin/ /usr/local/bin/

# Install dumb-init
RUN \
  apk add --no-cache --update python3 python3-dev py-pip build-base && \
  pip install dumb-init && \
  apk del python3 python3-dev py-pip build-base && \
  rm -rf /var/cache/apk/* && :

# Install various packages
RUN apk add --no-cache git curl zsh emacs-nox ripgrep zerotier-one \
    openssh sudo go tcpdump strace tmux

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod a+x kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# Add local user (and grant it sudo access)
ARG USER
RUN sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+NOPASSWD:\s\+ALL\)/\1/' /etc/sudoers
RUN adduser -G wheel -s /bin/zsh -D ${USER}
RUN passwd -u ${USER}

# Install user's local stuff
WORKDIR /home/${USER}

# Generate host keys for sshd
RUN ssh-keygen -A

# NVM dependencies
RUN apk add -U curl bash ca-certificates openssl ncurses coreutils python2 make gcc g++ libgcc linux-headers grep util-linux binutils findutils

USER ${USER}

# SSH auth stuff
ARG AUTH_KEYS
RUN mkdir -m 700 .ssh
RUN echo ${AUTH_KEYS} | base64 -d > .ssh/authorized_keys
RUN chmod 600 .ssh/authorized_keys

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
