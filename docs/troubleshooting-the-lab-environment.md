# Troubleshooting the Lab Environment

Use this guide for host, Docker, and Containerlab failures. A scenario-induced
network failure inside a deployed lab belongs to the lab exercise and should
be investigated with the lab's evidence workflow.

## Start with the repository check

From the repository root:

```bash
make check
```

The check does not install packages or change networking. Address its first
reported error before continuing.

## Command not found

Identify which binary is missing:

```bash
command -v docker
command -v containerlab
```

If either command prints nothing, return to [Installing Docker and
Containerlab](installing-containerlab.md). After installation, open a new shell
so changes to `PATH` and group membership take effect.

## Cannot connect to the Docker daemon

Inspect the service without changing it:

```bash
docker version
docker info
systemctl status docker --no-pager
```

Common causes are a stopped daemon, a shell that has not picked up new group
membership, or an account without permission to use the Docker socket. Do not
make the socket world-writable. Follow Docker's [Linux post-installation
guidance] and remember that Docker access is effectively root-level access.

## Containerlab reports a permission error

Record the exact command and error, then check:

```bash
containerlab version
docker info
id
```

Containerlab needs privileges for Linux namespaces and links. Use the
installation method's documented privilege model. Do not add broad `sudo`
calls to repository scripts or disable mandatory access controls merely to
hide an error.

## Images will not download

Check free space and Docker's view of storage:

```bash
df -h
docker system df
```

Then confirm the host can reach the relevant registry through its approved
proxy or firewall. Do not run broad cleanup commands on a shared Docker host;
they can remove unrelated images and containers.

## A topology name already exists

Before removing anything, list Containerlab topologies and Docker resources:

```bash
containerlab inspect --all
docker ps -a
docker network ls
```

Use only the lab's `make destroy` target to remove its named resources. Do not
delete all Docker networks or containers.

## Host firewall or security policy conflicts

Collect evidence before changing policy:

```bash
sudo nft list ruleset
sudo sysctl net.ipv4.ip_forward
```

These commands reveal potentially sensitive host policy; share their output
only after review. Prefer a dedicated Linux VM over weakening firewall,
SELinux, AppArmor, endpoint security, or corporate policy on a workstation.

## Partial deployment or interrupted command

Do not manually remove arbitrary namespaces, links, or Docker networks. Once
implemented, the lab's `make destroy` target will be safe to run from partial
states and will target only its named topology. Until then, no topology exists
for this repository to clean up.

## Information to collect

If the issue remains, capture:

```bash
uname -a
cat /etc/os-release
docker version
docker info
containerlab version
```

Also record the repository revision with `git rev-parse HEAD` and the exact
failing command. Redact registry credentials, proxy credentials, private
addresses, and other sensitive details.

[Linux post-installation guidance]: https://docs.docker.com/engine/install/linux-postinstall/
