# Docker in Docker

Installs a rootless Docker engine for building and running containers inside the dev
container. The daemon runs as the remote user, so the dev container does not need
`privileged` and a member of the docker group cannot reach the host's devices.

## Requirements

The daemon only starts when the container it runs in permits the namespaces and mounts
RootlessKit creates. The consumer has to provide all of the following.

| Requirement | Why |
|---|---|
| A non-root `remoteUser` | The daemon runs as that user and refuses to start as root. |
| `no-new-privileges` unset | It makes the kernel ignore the file capabilities on `newuidmap` and `newgidmap`. |
| `apparmor=unconfined` | The default profile denies the mounts RootlessKit performs. |
| A seccomp profile allowing `clone`, `clone3`, `unshare`, `mount`, `umount2`, `pivot_root`, `setns` | The default profile gates them behind `CAP_SYS_ADMIN`, which the container does not hold. |

`test/docker-in-docker/seccomp.json` is the reference profile: Docker's default with those
syscalls opened and nothing else, so `kexec_load`, `init_module` and `swapon` stay denied.
It is a copy of the profile the consuming project ships, and the two have to be kept in
step by hand. The `rootless_daemon` scenario reaches it through `${localEnv:PWD}`, so run
`devcontainer features test` from the repository root.

Without these the entrypoint still hands off to the container command, so the dev
container comes up with the CLI on PATH and no daemon behind it.

## Limitations

No cgroup resource limits without a systemd user session, userspace networking through
slirp4netns, no ports below 1024, no host device passthrough, and no overlay networks, so
Swarm services and nested Kubernetes do not work. Pin `:1` for the rootful engine, which
is frozen and no longer maintained.
