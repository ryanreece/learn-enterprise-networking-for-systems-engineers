# Installing Docker and Containerlab

Native Ubuntu 24.04 LTS is the reference installation. These steps require
administrator access and change the Linux host by installing packages. Review
commands before running them, especially on a managed system.

The official upstream references are the [Docker Engine installation guide]
and the [Containerlab installation guide]. Prefer those references if package
names or repository instructions have changed.

## 1. Install base tools

On Ubuntu:

```bash
sudo apt update
sudo apt install -y ca-certificates curl git make openssh-client openssl ripgrep
```

## 2. Install Docker Engine

Follow Docker's official [Ubuntu installation instructions] to configure its
APT repository and install Docker Engine. Do not rely on a desktop-only Docker
client: Containerlab needs access to a running Linux Docker daemon.

Confirm both client and server respond:

```bash
docker version
docker info
```

If Docker reports permission denied, choose one of these approaches:

- run the lab from a dedicated account configured for Docker access; or
- follow Docker's [Linux post-installation steps] to grant the account access.

Membership in the `docker` group is effectively root-level access. Use it only
on a host or VM where that trust is appropriate. Log out and back in after
changing group membership.

## 3. Install the development-target Containerlab release

The repository currently targets Containerlab 0.79.0. The upstream installer
can request that exact version:

```bash
bash -c "$(curl -sL https://get.containerlab.dev)" -- -v 0.79.0
```

This downloads and executes the official installer and may invoke `sudo`.
Learners who cannot approve a remote script should instead download and verify
the matching package from the [Containerlab releases page], then install it
with the host package manager.

Confirm the installed release:

```bash
containerlab version
```

The lab's pinned version may change after end-to-end validation. Use the
version recorded in the lab README for a published release.

## 4. Validate the repository prerequisites

From the repository root:

```bash
make check
```

This root check is read-only. It confirms that Docker and Containerlab exist
and that the current user can reach the Docker daemon. Lab 01 provides a more
specific `make check` from its own directory.

If validation fails, see [Troubleshooting the Lab Environment].

[Containerlab installation guide]: https://containerlab.dev/install/
[Containerlab releases page]: https://github.com/srl-labs/containerlab/releases
[Docker Engine installation guide]: https://docs.docker.com/engine/install/
[Linux post-installation steps]: https://docs.docker.com/engine/install/linux-postinstall/
[Troubleshooting the Lab Environment]: troubleshooting-the-lab-environment.md
[Ubuntu installation instructions]: https://docs.docker.com/engine/install/ubuntu/
