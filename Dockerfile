FROM steamcmd/steamcmd:ubuntu-24

ARG GID=1000
ARG UID=1000

ENV AUTOSAVENUM="5" \
    DEBIAN_FRONTEND="noninteractive" \
    DEBUG="false" \
    DISABLESEASONALEVENTS="false" \
    GAMECONFIGDIR="/config/gamefiles/FactoryGame/Saved" \
    GAMESAVESDIR="/home/steam/.config/Epic/FactoryGame/Saved/SaveGames" \
    LOG="false" \
    MAXOBJECTS="2162688" \
    MAXPLAYERS="4" \
    MAXTICKRATE="30" \
    MULTIHOME="::" \
    PGID="1000" \
    PUID="1000" \
    SERVERGAMEPORT="7777" \
    SERVERMESSAGINGPORT="8888" \
    SERVERSTREAMING="true" \
    SKIPUPDATE="false" \
    STEAMAPPID="1690800" \
    STEAMBETA="false" \
    STEAMBETAID="" \
    STEAMBETAKEY="" \
    TIMEOUT="30" \
    VMOVERRIDE="false" \
    SFTP_USERNAME="steam" \
    SFTP_PASSWORD="satisfactory-sftp-pass" \
    TS_AUTHKEY="" \
    TS_HOSTNAME="satisfactory-server" \
    GC_TIME_BETWEEN_PURGING="30" \
    GC_NUM_OBJECTS_PER_STEP="2000" \
    STEAMCMD_VALIDATE="false" \
    TZ="UTC"

# hadolint ignore=DL3008
RUN set -x \
 && apt-get update \
 && apt-get install -y gosu xdg-user-dirs curl jq tzdata openssh-server supervisor --no-install-recommends \
 && curl -fsSL https://tailscale.com/install.sh | sh \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd -g ${GID} steam \
 && useradd -u ${UID} -g ${GID} -ms /bin/bash steam \
 && mkdir -p /home/steam/.local/share/Steam/ \
 && cp -R /root/.local/share/Steam/steamcmd/ /home/steam/.local/share/Steam/steamcmd/ \
 && chown -R ${UID}:${GID} /home/steam/.local/ \
 && curl -sSL -o /usr/local/bin/ficsit https://github.com/satisfactorymodding/ficsit-cli/releases/download/v0.6.1/ficsit_linux_amd64 \
 && chmod +x /usr/local/bin/ficsit \
 && ln -s /usr/local/bin/ficsit /usr/local/bin/ficsit-cli \
 && mkdir -p /var/run/sshd \
 && chmod 0755 /var/run/sshd \
 && gosu nobody true

RUN mkdir -p /config \
 && chown steam:steam /config

COPY init.sh /
COPY --chown=steam:steam healthcheck.sh run.sh tailscale-up.sh /home/steam/

RUN chmod +x /init.sh /home/steam/healthcheck.sh /home/steam/run.sh /home/steam/tailscale-up.sh

HEALTHCHECK --timeout=30s --start-period=300s CMD bash /home/steam/healthcheck.sh

WORKDIR /config
ARG VERSION="DEV"
ENV VERSION=$VERSION
LABEL version=$VERSION
STOPSIGNAL SIGINT
EXPOSE 7777/udp 7777/tcp 8888/tcp 2222/tcp

ENTRYPOINT [ "/init.sh" ]