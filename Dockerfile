FROM ghcr.io/canh25xp/dotfiles-debian:minimal-v2.0.2

USER root

RUN apt-get update && apt-get install -y --no-install-recommends nano

# Copy users configuration
COPY users.json /users.json

# Copy dotfiles
COPY dotfiles/ /dotfiles/

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /var/log && touch /var/log/lastlog && chmod 644 /var/log/lastlog

# Install nano but set nvim as default editor
RUN update-alternatives --set editor /usr/bin/nvim

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
