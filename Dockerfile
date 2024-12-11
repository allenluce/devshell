# Prepare emacs
FROM oraclelinux:8 AS emacs-builder

# For building texinfo&emacs
RUN dnf -y install autoconf make perl gcc ncurses-devel automake \
  libtool gettext gnutls-devel xz git

# Make help2man
RUN cd /tmp \
  && curl -LO https://ftp.gnu.org/gnu/help2man/help2man-1.49.3.tar.xz \
  && xzcat /tmp/help2man-1.49.3.tar.xz | tar -xf - \
  && cd help2man-1.49.3 && ./configure && make install \
  && rm -rf /tmp/help2man-1.49.3

# Make texinfo
RUN git clone https://git.savannah.gnu.org/git/texinfo.git /tmp/texinfo \
  && cd /tmp/texinfo \
  && git checkout texinfo-6.8 \
  && ./autogen.sh && ./configure && make install \
  && rm -rf /tmp/texinfo

# Make emacs
RUN git clone https://git.savannah.gnu.org/git/emacs.git /tmp/emacs
WORKDIR /tmp/emacs
RUN git checkout emacs-30.0.92
RUN ./autogen.sh && ./configure --prefix=/opt/emacs
RUN make lib
RUN make lib-src
RUN make src
RUN make || make || make || make || make || make || make || make || make || make
RUN make install
RUN rm -rf /tmp/emacs

# Create main image
FROM oraclelinux:8

RUN dnf -y install oraclelinux-developer-release-el8 oracle-epel-release-el8
RUN dnf -y install dumb-init git curl bash zsh ripgrep openssh sudo \
  tcpdump strace tmux ca-certificates util-linux make binutils findutils \
  man-db man-pages mlocate python36-oci-cli

# Bring emacs over from builder
COPY --from=emacs-builder /opt/emacs/ /opt/emacs/

# Get mlocate initialized
RUN updatedb

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod a+x kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# Add local user (and grant it sudo access)
ARG USER
RUN adduser -G wheel -s /usr/bin/zsh -M ${USER}
RUN echo "${USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USER} && chmod 0440 /etc/sudoers.d/${USER}

# Install user's local stuff
WORKDIR /home/${USER}
RUN chown ${USER}:${USER} /home/${USER}

# Generate host keys for sshd
RUN ssh-keygen -A

USER ${USER}

# SSH auth stuff
ARG AUTHORIZED_KEYS
RUN mkdir -m 700 .ssh
RUN echo ${AUTHORIZED_KEYS} | base64 -d > .ssh/authorized_keys
RUN chmod 600 .ssh/authorized_keys

# Install prezto
COPY --chown=${USER} .zprezto/ .zprezto/
COPY --chown=${USER} .p10k.zsh .p10k.zsh
RUN for rcfile in $(ls -d .zprezto/runcoms/* | grep -v README.md); do ln -s $rcfile .${rcfile##*/}; done

# Install Emacs Prelude
RUN curl -L https://git.io/epre | sh
RUN /opt/emacs/bin/emacs --daemon # Pre-compile .el files

# Start SSHD and sleep for 10 years
ENTRYPOINT ["/usr/bin/dumb-init", "zsh", "-c", "sudo /usr/sbin/sshd && exec $*", "--"]
CMD ["/bin/sleep", "3650d"]
