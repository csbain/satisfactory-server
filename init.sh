#!/bin/bash

set -e

printf "===== Satisfactory Server %s =====\\nhttps://github.com/csbain/satisfactory-server\\n\\n" "$VERSION"

MSGERROR="\033[0;31mERROR:\033[0m"
MSGWARNING="\033[0;33mWARNING:\033[0m"
NUMCHECK='^[0-9]+$'
RAMAVAILABLE=$(awk '/MemAvailable/ {printf( "%d\n", $2 / 1024000 )}' /proc/meminfo)

export CURRENTGID=$(id -g)
export CURRENTUID=$(id -u)

# Rename the 'steam' user if a custom SFTP_USERNAME is requested and we are root
export SFTP_USERNAME="${SFTP_USERNAME:-steam}"
if [[ "$CURRENTUID" -eq "0" ]] && [[ "$SFTP_USERNAME" != "steam" ]]; then
    printf "Renaming 'steam' user to '%s' to support custom SFTP_USERNAME...\\n" "$SFTP_USERNAME"
    usermod -l "$SFTP_USERNAME" steam
fi

export HOME="/home/steam"
export STEAMGID=$(id -g "$SFTP_USERNAME")
export STEAMUID=$(id -u "$SFTP_USERNAME")
export USER="$SFTP_USERNAME"

if [[ "${DEBUG,,}" == "true" ]]; then
    printf "Debugging enabled (the container will exit after printing the debug info)\\n\\nPrinting environment variables:\\n"
    export

    echo "
System info:
OS:  $(uname -a)
CPU: $(lscpu | grep '^Model name:' | sed 's/Model name:[[:space:]]*//g')
RAM: $(awk '/MemAvailable/ {printf( "%d\n", $2 / 1024000 )}' /proc/meminfo)GB/$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024000 )}' /proc/meminfo)GB
HDD: $(df -h | awk '$NF=="/"{printf "%dGB/%dGB (%s used)\n", $3,$2,$5}')"
    printf "\\nCurrent version:\\n%s" "${VERSION}"
    printf "\\nCurrent user:\\n%s" "$(id)"
    printf "\\nProposed user:\\nuid=%s(?) gid=%s(?) groups=%s(?)\\n" "$PUID" "$PGID" "$PGID"
    printf "\\nExiting...\\n"
    exit 1
fi

# check that the cpu isn't generic, as Satisfactory will normally crash
if [[ "$VMOVERRIDE" == "true" ]]; then
    printf "${MSGWARNING} VMOVERRIDE is enabled, skipping CPU model check. Satisfactory might crash!\\n"
else
    cpu_model=$(lscpu | grep 'Model name:' | sed 's/Model name:[[:space:]]*//g')
    if [[ "$cpu_model" == "Common KVM processor" || "$cpu_model" == *"QEMU"* ]]; then
        printf "${MSGERROR} Your CPU model is configured as \"${cpu_model}\", which will cause Satisfactory to crash.\\nIf you have control over your hypervisor (ESXi, Proxmox, etc.), you should be able to easily change this.\\nOtherwise contact your host/administrator for assistance.\\n"
        exit 1
    fi
fi

printf "Checking available memory: %sGB detected\\n" "$RAMAVAILABLE"
if [[ "$RAMAVAILABLE" -lt 8 ]]; then
    printf "${MSGWARNING} You have less than the required 8GB minimum (%sGB detected) of available RAM to run the game server.\\nThe server will likely run fine, though may run into issues in the late game (or with 4+ players).\\n" "$RAMAVAILABLE"
fi

# prevent large logs from accumulating by default
if [[ "${LOG,,}" != "true" ]]; then
    printf "Clearing old Satisfactory logs (set LOG=true to disable this)\\n"
    if [ -d "/config/gamefiles/FactoryGame/Saved/Logs" ] && [ -n "$(find /config/gamefiles/FactoryGame/Saved/Logs -type f -print -quit)" ]; then
        rm -r /config/gamefiles/FactoryGame/Saved/Logs/* || true
    fi
fi

if [[ "$CURRENTUID" -ne "0" ]]; then
    if [[ "$STEAMUID" -ne "$CURRENTUID" ]] || [[ "$STEAMGID" -ne $(id -g) ]]; then
        printf "${MSGERROR} Current user (%s:%s) is not root (0:0), and doesn't match the steam user/group (%s:%s).\\nTo run the container as non-root with a UID/GID that differs from the steam user, you must build the Docker image with the UID and GID build arguments set.\\n" "$CURRENTUID" "$CURRENTGID" "$STEAMUID" "$STEAMGID"
        exit 1
    fi

    printf "${MSGWARNING} Running as non-root user (%s:%s).\\n" "$CURRENTUID" "$CURRENTGID"
fi

if ! [[ "$PGID" =~ $NUMCHECK ]] ; then
    printf "${MSGWARNING} Invalid group id given: %s\\n" "$PGID"
    PGID="1000"
elif [[ "$PGID" -eq 0 ]]; then
    printf "${MSGERROR} PGID/group cannot be 0 (root)\\n"
    exit 1
fi

if ! [[ "$PUID" =~ $NUMCHECK ]] ; then
    printf "${MSGWARNING} Invalid user id given: %s\\n" "$PUID"
    PUID="1000"
elif [[ "$PUID" -eq 0 ]]; then
    printf "${MSGERROR} PUID/user cannot be 0 (root)\\n"
    exit 1
fi

if [[ "$CURRENTUID" -eq "0" ]]; then
    if [[ $(getent group $PGID | cut -d: -f1) ]]; then
        usermod -a -G "$PGID" "$SFTP_USERNAME"
    else
        groupmod -g "$PGID" steam
    fi

    if [[ $(getent passwd ${PUID} | cut -d: -f1) ]]; then
        USER=$(getent passwd $PUID | cut -d: -f1)
    else
        usermod -u "$PUID" "$SFTP_USERNAME"
    fi
fi

if [[ ! -w "/config" ]]; then
    echo "The current user does not have write permissions for /config"
    exit 1
fi

mkdir -p \
    /config/backups \
    /config/gamefiles \
    /config/logs/steam \
    /config/saved/blueprints \
    /config/saved/server \
    /config/ficsit-cli \
    /home/steam/.config \
    "${GAMECONFIGDIR}/Config/LinuxServer" \
    "${GAMECONFIGDIR}/Logs" \
    "${GAMESAVESDIR}/server" \
    /home/steam/.steam/root \
    /home/steam/.steam/steam \
    || exit 1

echo "Satisfactory logs can be found in /config/gamefiles/FactoryGame/Saved/Logs" > /config/logs/satisfactory-path.txt

rm -rf /home/steam/.config/ficsit
ln -sf /config/ficsit-cli /home/steam/.config/ficsit

# Prepare SSHD Configuration File
mkdir -p /etc/ssh
cat <<EOF > /etc/ssh/sshd_config_satisfactory
Port 2222
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
UsePAM yes
Subsystem sftp internal-sftp
X11Forwarding no
AllowTcpForwarding no
PrintMotd no
PasswordAuthentication yes
PermitRootLogin no
AllowUsers $SFTP_USERNAME
EOF

if [[ "$CURRENTUID" -eq "0" ]]; then
    # Update home directory of custom sftp user to /config for SFTP landing
    usermod -d /config "$SFTP_USERNAME" || true
    
    # Generate host keys if missing
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        echo "Generating SSH host keys..."
        ssh-keygen -A
    fi
    
    # Update SFTP Password for custom sftp user
    if [ -z "$SFTP_PASSWORD" ]; then
        SFTP_PASSWORD="satisfactory-sftp-pass"
        printf "${MSGWARNING} SFTP_PASSWORD is not set. Defaulting to '%s'\\n" "$SFTP_PASSWORD"
    fi
    echo "$SFTP_USERNAME:$SFTP_PASSWORD" | chpasswd
    
    # Auto-add installation path for ficsit-cli
    gosu "$SFTP_USERNAME" ficsit installation add /config/gamefiles || true
else
    # Rootless fallback
    ficsit installation add /config/gamefiles || true
fi

# Generate supervisord configuration
mkdir -p /etc/supervisor/conf.d
export EXTRA_ARGS="$@"

if [[ "$CURRENTUID" -eq "0" ]]; then
    # Running as root: We manage both the game server and sshd via supervisord
    chown -R "$PUID":"$PGID" /config /home/steam /tmp/dumps
    cat <<EOF > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
logfile=/dev/stdout
logfile_maxbytes=0

[program:satisfactory]
command=/home/steam/run.sh %(environ_EXTRA_ARGS)s
user=%(environ_SFTP_USERNAME)s
directory=/config
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
stopwaitsecs=60

[program:sshd]
command=/usr/sbin/sshd -D -e -f /etc/ssh/sshd_config_satisfactory
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
EOF

    # Handle Tailscale setup if authkey is provided
    if [[ -n "$TS_AUTHKEY" ]]; then
        mkdir -p /config/tailscale /var/run/tailscale
        cat <<EOF >> /etc/supervisor/conf.d/supervisord.conf

[program:tailscaled]
command=/usr/sbin/tailscaled --state=/config/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true

[program:tailscale-up]
command=/home/steam/tailscale-up.sh
autorestart=false
startsecs=0
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF
    fi
    exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
else
    # Running within a rootless environment: No sshd or tailscale permitted, run satisfactory under supervisor
    cat <<EOF > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
logfile=/dev/stdout
logfile_maxbytes=0

[program:satisfactory]
command=/home/steam/run.sh %(environ_EXTRA_ARGS)s
directory=/config
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
stopwaitsecs=60
EOF
    exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
