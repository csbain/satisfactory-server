# Satisfactory Server

![Satisfactory](https://raw.githubusercontent.com/csbain/satisfactory-server/main/.github/logo.png "Satisfactory logo")

![Release](https://img.shields.io/github/v/release/csbain/satisfactory-server)
![Docker Pulls](https://img.shields.io/docker/pulls/csbain/satisfactory-server)
![Docker Stars](https://img.shields.io/docker/stars/csbain/satisfactory-server)
![Image Size](https://img.shields.io/docker/image-size/csbain/satisfactory-server)

This is a Dockerized version of the [Satisfactory](https://store.steampowered.com/app/526870/Satisfactory/) dedicated
server.

### [Experiencing issues? Check our Troubleshooting FAQ wiki!](https://github.com/csbain/satisfactory-server/wiki/Troubleshooting-FAQ)

### [Upgrading for Satisfactory 1.1](https://github.com/csbain/satisfactory-server/wiki/Upgrading-for-1.1)

## Setup

The server may run on less than 8GB of RAM, though 8GB - 16GB is still recommended per
the [the official wiki](https://satisfactory.wiki.gg/wiki/Dedicated_servers#Requirements). You may need to increase the
container's defined `--memory` restriction as you approach the late game (or if you're playing with many 4+ players)

You'll need to bind a local directory to the Docker container's `/config` directory. This directory will hold the
following directories:

- `/backups` - the server will automatically backup your saves when the container first starts
- `/gamefiles` - this is for the game's files. They're stored outside the container to avoid needing to redownload
  8GB+ every time you want to rebuild the container
- `/logs` - this holds Steam's logs, and contains a pointer to Satisfactory's logs (empties on startup unless
  `LOG=true`)
- `/saved` - this contains the game's blueprints, saves, and server configuration

Before running the server image, you should find your user ID that will be running the container. This isn't necessary
in most cases, but it's good to find out regardless. If you're seeing `permission denied` errors, then this is probably
why. Find your ID in `Linux` by running the `id` command. Then grab the user ID (usually something like `1000`) and pass
it into the `-e PGID=1000` and `-e PUID=1000` environment variables.

Run the Satisfactory server image like this (this is one command, make sure to copy all of it):<br>

```bash
docker run \
--detach \
--name=satisfactory-server \
--hostname satisfactory-server \
--restart unless-stopped \
--volume ./satisfactory-server:/config \
--env MAXPLAYERS=4 \
--env PGID=1000 \
--env PUID=1000 \
--env STEAMBETA=false \
--env SFTP_PASSWORD=satisfactory-sftp-pass \
--memory-reservation=8G \
--memory 16G \
--publish 7777:7777/tcp \
--publish 7777:7777/udp \
--publish 8888:8888/tcp \
--publish 2222:2222/tcp \
ghcr.io/csbain/satisfactory-server:latest
```

<details>
<summary>Explanation of the command</summary>

* `--detach` -> Starts the container detached from your terminal<br>
  If you want to see the logs replace it with `--sig-proxy=false`
* `--name` -> Gives the container a unqiue name
* `--hostname` -> Changes the hostname of the container
* `--restart unless-stopped` -> Automatically restarts the container unless the container was manually stopped
* `--volume` -> Binds the Satisfactory config folder to the folder you specified
  Allows you to easily access your savegames
* For the environment (`--env`) variables please
  see [here](https://github.com/csbain/satisfactory-server#environment-variables)
* `--memory-reservation=8G` -> Reserves 8GB RAM from the host for the container's use
* `--memory 16G` -> Restricts the container to 16GB RAM
* `--publish` -> Specifies the ports that the container exposes (including 2222 for embedded SFTP)<br>

</details>

### Docker Compose

If you're using [Docker Compose](https://docs.docker.com/compose/):

```yaml
services:
  satisfactory-server:
    container_name: 'satisfactory-server'
    hostname: 'satisfactory-server'
    image: 'ghcr.io/csbain/satisfactory-server:latest'
    ports:
      - '7777:7777/tcp'
      - '7777:7777/udp'
      - '8888:8888/tcp'
      - '2222:2222/tcp'
    volumes:
      - './satisfactory-server:/config'
    environment:
      - MAXPLAYERS=4
      - PGID=1000
      - PUID=1000
      - STEAMBETA=false
      - SFTP_PASSWORD=satisfactory-sftp-pass
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 16G
        reservations:
          memory: 8G
```

### unRAID Template

If you are running this container on **unRAID**, an XML template is included in this repository under:
[unraid-templates/satisfactory-server.xml](unraid-templates/satisfactory-server.xml)

You can copy this XML file onto your unRAID flash drive at `/boot/config/plugins/dockerMan/templates-user/` to import the template directly into your Unraid Docker Manager interface, or add it to Community Applications.

### Updating

The game automatically updates when the container is started or restarted (unless you set `SKIPUPDATE=true`).

To update the container image itself:

#### Docker Run

```shell
docker pull ghcr.io/csbain/satisfactory-server:latest
docker stop satisfactory-server
docker rm satisfactory-server
docker run ...
```

#### Docker Compose

```shell
docker compose pull
docker compose up -d
```

### SSL Certificate with Certbot (Optional)

You can use Certbot with Let's Encrypt to issue a signed SSL certificate for your server. Without this,
Satisfactory will use a self-signed SSL certificate, requiring players to manually confirm them when they initially
connect. If you're experiencing connectivity issues since issuing a certificate, check the link below for known issues.

[Learn more](https://github.com/csbain/satisfactory-server/tree/main/ssl).

### Kubernetes

If you are running a [Kubernetes](https://kubernetes.io) cluster, we do have
a [service.yaml](https://github.com/csbain/satisfactory-server/tree/main/cluster/service.yaml)
and [statefulset.yaml](https://github.com/csbain/satisfactory-server/tree/main/cluster/statefulset.yaml) available
under the [cluster](https://github.com/csbain/satisfactory-server/tree/main/cluster) directory of this repo, along with
an example [values.yaml](https://github.com/csbain/satisfactory-server/tree/main/cluster/values.yaml) file.

If you are using [Helm](https://helm.sh), you can find charts for this repo on
[ArtifactHUB](https://artifacthub.io/packages/search?ts_query_web=satisfactory&sort=relevance&page=1). The
[k8s-at-home](https://github.com/k8s-at-home/charts) helm chart for Satisfactory can be installed with the below (please
see `cluster/values.yaml` for more information).

```bash
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update
helm install satisfactory k8s-at-home/satisfactory -f values.yaml
```

## Environment Variables

| Parameter               |  Default  | Function                                                  |
|-------------------------|:---------:|-----------------------------------------------------------|
| `AUTOSAVENUM`           |    `5`    | number of rotating autosave files                         |
| `DEBUG`                 |  `false`  | for debugging the server                                  |
| `DISABLESEASONALEVENTS` |  `false`  | disable the FICSMAS event (you miserable bastard)         |
| `LOG`                   |  `false`  | disable Satisfactory log pruning                          |
| `MAXOBJECTS`            | `2162688` | set the object limit for your server                      |
| `MAXPLAYERS`            |    `4`    | set the player limit for your server                      |
| `MAXTICKRATE`           |   `30`    | set the maximum sim tick rate for your server             |
| `MULTIHOME`             |   `::`    | set the server's listening interface (usually not needed) |
| `PGID`                  |  `1000`   | set the group ID of the user the server will run as       |
| `PUID`                  |  `1000`   | set the user ID of the user the server will run as        |
| `SERVERGAMEPORT`        |  `7777`   | set the game's server port                                |
| `SERVERMESSAGINGPORT`   |  `8888`   | set the game's messaging port (internally and externally) |
| `SERVERSTREAMING`       |  `true`   | toggle whether the game utilizes asset streaming          |
| `SKIPUPDATE`            |  `false`  | avoid updating the game on container start/restart        |
| `STEAMBETA`             |  `false`  | set experimental game version                             |
| `STEAMBETAID`           |           | set a custom beta game version (for testing)              |
| `STEAMBETAKEY`          |           | set password for the beta game version (for testing)      |
| `TIMEOUT`               |   `30`    | set client timeout (in seconds)                           |
| `VMOVERRIDE`            |  `false`  | skips the CPU model check (should not ordinarily be used) |
| `SFTP_USERNAME`         |   `steam` | username for SFTP server access (used for mod managers) |
| `SFTP_PASSWORD`         | `satisfactory-sftp-pass` | password for SFTP server access (used for mod managers) |
| `TS_AUTHKEY`            |           | auth key to enable embedded Tailscale connection          |
| `TS_HOSTNAME`           | `satisfactory-server` | hostname for the server on your Tailnet             |
| `GC_TIME_BETWEEN_PURGING`|   `30`    | Unreal Engine Garbage Collection frequency (seconds) to reduce hitching |
| `GC_NUM_OBJECTS_PER_STEP`|  `2000`   | Max objects to purge per Garbage Collection step           |
| `STEAMCMD_VALIDATE`     |  `false`  | set to true to force full verification of all game files   |
| `TZ`                    |   `UTC`   | set container timezone for aligned logs and backup times   |

## Experimental Branch

If you want to run a server for the Experimental version of the game, set the `STEAMBETA` environment variable to
`true`.

## Modding

Mod support is fully integrated into this Docker container. You have two options for managing mods:

### 1. Remote Mod Management (Recommended)
You can use the desktop **Satisfactory Mod Manager (SMM)** from your client PC to manage the server's mods over SFTP:
1. Open SMM on your PC and navigate to the **"Manage Servers"** section.
2. Click **"Add"** and select the **SFTP** protocol.
3. Enter your server's credentials:
   - **Host/IP:** Your server's IP address.
   - **Port:** `2222` (default embedded SFTP port).
   - **Username:** The username set in your `SFTP_USERNAME` environment variable (defaults to `steam`).
   - **Password:** The password set in your `SFTP_PASSWORD` environment variable.
4. Set the path to `/config/gamefiles` (the Satisfactory installation directory).
5. SMM will automatically connect, install SML (Satisfactory Mod Loader), and allow you to toggle mods on/off directly from your PC.

### 2. Local CLI Mod Management (`ficsit-cli`)
For command-line mod management directly inside the container, we have embedded **`ficsit-cli`** (v0.6.1):
1. Execute the mod manager TUI by running:
   ```bash
   docker exec -it satisfactory-server ficsit
   ```
2. The CLI is pre-configured to detect your server's game files in `/config/gamefiles`. You can browse and manage your mods directly in the terminal interface. All configurations will be stored and persisted in `/config/ficsit-cli`.

## Tailscale Integration

You can bake a **Tailscale** connection directly into this container, exposing both the game ports and the SFTP server port on your private Tailnet without needing to port-forward or open firewalls on your router.

### Setup Requirements
Since Tailscale manages network interfaces inside the container, you **must** pass the following runtime privileges:
- **Capabilities:** `--cap-add=NET_ADMIN` and `--cap-add=NET_RAW`
- **Devices:** `--device=/dev/net/tun`

### How to use:
1. Generate an **Auth Key** in your [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys).
2. Start the container with your key passed as the `TS_AUTHKEY` environment variable.
3. The server will boot, automatically start the Tailscale daemon (`tailscaled`), register itself to your Tailnet under your specified `TS_HOSTNAME`, and save its state securely to `/config/tailscale` so it keeps the same IP address on rebuilds.
4. Simply connect your game client or SFTP client (SMM) using the server's **Tailscale IP address**!
   - **All Ports Exposed**: The game server port `7777` (UDP/TCP), query/messaging port `8888` (TCP), and SFTP port `2222` (TCP) are automatically exposed on the `tailscale0` VPN interface inside the container. No router port forwarding or firewall rules are required to connect.

## Custom Image Builds via GHCR

This repository is pre-configured with a GitHub Actions workflow that automatically compiles and pushes the Docker image to your personal **GitHub Container Registry (GHCR)** on every push to the `main` branch or when a release tag is created.

To run your own custom-built container image instead of the default one:
- Replace `ghcr.io/csbain/satisfactory-server:latest` in your Docker command, Docker Compose file, or Unraid template with:
  ```text
  ghcr.io/YOUR_GITHUB_USERNAME/satisfactory-server:latest
  ```
  *(Make sure to replace `YOUR_GITHUB_USERNAME` with your lowercase GitHub username/org name).*

## How to Improve the Multiplayer Experience

The [Satisfactory Wiki](https://satisfactory.wiki.gg/wiki/Multiplayer#Engine.ini) recommends a few config tweaks for your client to really get the best out of multiplayer:

- Press `WIN + R`
- Enter `%localappdata%/FactoryGame/Saved/Config/Windows`
- Copy the config data from the wiki into the respective files
- Right-click each of the 3 config files (Engine.ini, Game.ini, Scalability.ini)
- Go to Properties > tick Read-only under the attributes

## unRAID Performance Optimizations

If you are running this container on **unRAID** (especially on multi-socket server hardware), follow these optimizations to prevent late-game lag and autosave stutters:

### 1. Bypass FUSE Overhead
By default, mapping to `/mnt/user/appdata/...` routes disk writes through unRAID's FUSE filesystem layer, which consumes significant CPU and can cause write-stutters during autosaves.
- **Optimization:** Map the container's `/config` directory directly to your SSD cache pool path (e.g. `/mnt/cache/appdata/satisfactory-server`).

### 2. NUMA-Aware CPU Pinning
Satisfactory's game loop is heavily single-threaded. On multi-socket systems, crossing CPU sockets to access memory (NUMA misses) introduces high latency.
- **Optimization:** Pin the container to physical cores on a **single CPU socket** (e.g. socket 0).
- Run `numactl -H` in the unRAID terminal to identify core assignments, then use the CPU pinning tool in the Docker template settings to select physical cores on socket 0 only.
- In unRAID global settings (Settings -> CPU Pinning), isolate these cores to prevent unRAID from scheduling other containers or OS tasks on them.

### 3. Exclude GPU Allocations
The dedicated server is fully headless (`-nullrhi`) and cannot utilize graphics hardware. Do not pass GPU variables or runtime flags (like `--runtime=nvidia`) to this container. Save your GPU resources for transcoding or VM passthroughs.

### 4. Scheduled Restarts (Memory Leak Refresh)
Dedicated game servers running on Unreal Engine can accumulate memory leaks over extended periods.
- **Optimization:** Use unRAID's User Scripts plugin or a host cron job to run `docker restart satisfactory-server` once every 24–48 hours (e.g., at 4:00 AM) to clear server memory. Since we use `supervisord` with a 60-second graceful exit timeout, it is completely safe.

### 5. Keep Server Tickrate at 30
Avoid increasing the `MAXTICKRATE` environment variable to 60 or 120 on lower-frequency server CPUs (like Intel Xeon E5 v3/v4).
- **Optimization:** Keeping the tickrate at 30 ensures the single-threaded simulation loop has ample time to process complex late-game factory calculations without falling behind and causing rubber-banding.

## Running as Non-Root User

By default, the container runs with root privileges but executes Satisfactory under `1000:1000`. If your host's user and
group IDs are `1000:1000`, you can run the entire container as non-root using Docker's `--user` directive. For different
user/group IDs, you'll need to clone and rebuild the image with your specific UID/GID:

### Building Non-Root Image

1. Clone the repository:

```shell
git clone https://github.com/csbain/satisfactory-server.git
```

2. Create a docker-compose.yml file with your desired UID/GID as build args (note that the `PUID` and `PGID` environment
   variables will no longer be needed):

```yaml
services:
  satisfactory-server:
    container_name: 'satisfactory-server'
    hostname: 'satisfactory-server'
    build:
      context: .
      args:
        UID: 1001  # Your desired UID
        GID: 1001  # Your desired GID
    user: "1001:1001"  # Must match UID:GID above
    ports:
      - '7777:7777/tcp'
      - '7777:7777/udp'
      - '8888:8888/tcp'
    volumes:
      - './satisfactory-server:/config'
    environment:
      - MAXPLAYERS=4
      - STEAMBETA=false
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 4G
```

3. Build and run the container:

```shell
docker compose up -d
```

## Known Issues

- The container is run as `root` by default. You can provide your own user and group using Docker's `--user` directive;
  however, if your proposed user and group aren't `1000:1000`, you'll need to rebuild the image (as outlined above).
- The server log will show various errors; most of which can be safely ignored. As long as the container continues to
  run and your log looks similar to the example log, the server should be functioning just
  fine: [example log](https://github.com/csbain/satisfactory-server/blob/main/server.log)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=csbain/satisfactory-server&type=Date)](https://star-history.com/#csbain/satisfactory-server&Date)
