# Environment Requirements

This guide describes the host needed for the isolated Containerlab labs. Lab
01 Part A runs on the learner's own computer and does not require Containerlab.

## Reference environment

The initial development target is:

- Ubuntu 24.04 LTS on x86_64 or arm64
- Docker Engine with a running Linux container daemon
- Containerlab 0.79.0
- Git, GNU Make, Bash, `curl`, and standard Linux command-line tools

This is a development target, not a completed compatibility claim. Lab 01 has
not yet been deployed and tested end to end. Its README will record the actual
last-tested host, Docker, Containerlab, and image versions once that validation
has occurred.

See [Supported Platforms](supported-platforms.md) before using another host.

## Host resources

The following provisional allocation is suitable for developing Lab 01 and
leaves room for local image builds:

- 2 CPU cores
- 4 GiB RAM
- 10 GiB free disk space
- Internet access for the initial package and image downloads

The lab must not require Internet access after its images have been obtained.
These resource figures will be measured and updated during end-to-end testing.

## Privileges and kernel behavior

Containerlab creates Linux network namespaces, virtual Ethernet links, and
container networks. The learner therefore needs:

- permission to run Docker containers;
- permission to run Containerlab's privileged networking operations;
- a Linux kernel that supports network namespaces, veth devices, forwarding,
  and nftables; and
- no local security policy that prevents the required namespace or virtual
  link operations.

Do not loosen a production host's security controls for a course lab. Use a
dedicated Linux VM if the workstation is centrally managed or shared.

## Required software

Install these before cloning and running an isolated lab:

| Tool | Purpose | Validation |
| --- | --- | --- |
| Git | Obtain and update the repository | `git --version` |
| GNU Make | Provide the learner command interface | `make --version` |
| Bash | Run lifecycle scripts | `bash --version` |
| Docker Engine | Run lab containers | `docker version` |
| Containerlab | Create the lab topology | `containerlab version` |
| curl | Download packages and inspect Part A HTTP transactions | `curl --version` |

The future Lab 01 `make check` will validate additional kernel and permission
requirements without changing the host. The current root `make check` verifies
that Docker and Containerlab are installed and that the Docker daemon is
reachable.

## Network and safety requirements

- Use only a Part A target you own or are explicitly authorized to test.
- Allow outbound HTTPS long enough to install packages and pull images.
- Do not bind the future lab application to a host or public interface.
- Do not alter the host DNS, routes, firewall, hosts file, or trust store for
  Part A.
- Keep enough access to the host or VM to recover if local firewall software
  conflicts with container networking.

Continue with [Installing Containerlab](installing-containerlab.md).
