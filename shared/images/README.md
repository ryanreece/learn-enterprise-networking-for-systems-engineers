# Shared Container Images

These images provide course-wide networking tools without installing packages
every time a topology starts. They are built locally and are not published by
this repository.

## Images

| Local tag | Purpose |
| --- | --- |
| `reeceai-course/network-toolbox:0.2.0` | Client diagnostics with DNS, route, transport, TLS, HTTP, packet capture, and key-only SSH access |
| `reeceai-course/linux-router:0.1.0` | Linux forwarding and firewall diagnostics with nftables and connection tracking |

Both images use Alpine 3.24.2 pinned by its multi-platform image digest, and
their direct packages are pinned to the versions validated by this slice.
Image names and versions are centralized in `shared/scripts/common.sh`.

The toolbox SSH daemon disables password and keyboard-interactive login. Labs
must mount an explicit `authorized_keys` file and should not publish SSH to a
host or public interface.

## Build and test

From the repository root:

```bash
make build
make test
```

The smoke tests run each image with its network disabled. Command-presence
checks drop all Linux capabilities. Focused behavior checks then add only
`NET_RAW` to the toolbox and `NET_ADMIN` plus `NET_RAW` to the router. They
prove local probing, capture enumeration, forwarding state, nftables, and
connection tracking without attaching either container to a real network.

End-to-end forwarding and packet capture across links require an isolated
topology and will be tested in the next vertical slice.

## Runtime privileges

The Dockerfiles do not grant Linux capabilities. Each Containerlab topology
must add only the capabilities its nodes need. Lab 01 uses:

- the diagnostic client needs `NET_RAW` for packet capture and selected probes;
- the router needs `NET_ADMIN` for routes and nftables, plus `NET_RAW` for
  packet capture; and
- IP forwarding must be enabled explicitly on the router node.

Do not run either image with host networking or blanket `--privileged` access.
