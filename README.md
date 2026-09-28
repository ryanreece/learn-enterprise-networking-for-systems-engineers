# Enterprise Networking for Systems Engineers

This repository contains the executable labs for the Reece.AI course
**Enterprise Networking for Systems Engineers**. The labs teach networking by
asking you to establish a working transaction, introduce a controlled failure,
follow the evidence to the failing stage, repair it, and repeat the original
transaction.

The Reece.AI site is the canonical curriculum and teaching interface. This
repository holds the topologies, configurations, scripts, tests, and concise
operational instructions needed to run the labs.

> **Repository status:** Lab 01 has a runnable known-good Containerlab baseline
> with DNS, routed HTTPS, and lab-generated TLS certificates. Its deterministic
> The known-good topology and all four initial controlled failure scenarios
> have deterministic reset paths and lifecycle tests. Challenge mode and
> subsequent scenario expansion remain in development.

## Course links

The following are the intended publication URLs and must be confirmed before
the course is released:

- [Course: Enterprise Networking for Systems Engineers][course]
- [Lab 01: Locate the Failing Stage of a Connection][lab-01-page]

## Supported environment

Native Linux is the reference platform for Containerlab labs. Ubuntu 24.04 LTS
is the initial development target. macOS and Windows learners should use a
Linux virtual machine for the isolated labs; WSL2 remains best effort until the
repository's complete lifecycle has been tested there.

Start with these guides:

- [Environment requirements](docs/environment-requirements.md)
- [Installing Containerlab](docs/installing-containerlab.md)
- [Supported platforms](docs/supported-platforms.md)
- [Troubleshooting the lab environment](docs/troubleshooting-the-lab-environment.md)

## Common lab lifecycle

Every implemented lab will expose a small Make-based interface. From a lab
directory, the normal workflow will be:

```text
make check
make build
make deploy
make baseline
make scenario SCENARIO=<name>
make verify
make destroy
```

`baseline` proves the complete original transaction before a fault is added.
After troubleshooting and repairing the actual lab state, `verify` repeats
that same transaction. `reset` will be an escape hatch, not the normal repair
method.

Root-level commands cover repository-wide operations:

```text
make help
make check
make build
make lint
make test
```

Run `make help` to see which operations are available in the current
development phase.

## Labs

| Lab | Status | Outcome |
| --- | --- | --- |
| [01 — Locate the Failing Stage of a Connection](labs/01-locate-the-failing-stage/README.md) | Baseline and four core failures implemented | Locate a failure across DNS, local delivery, path, policy, transport, and TLS/application stages. |

## Safety and cost

Part A of Lab 01 observes a real connection and must target only a system you
own or are authorized to test. Part B will run inside an isolated Containerlab
topology, require no public cloud account, and expose no application service to
the public network.

Local container images and disk space are the only expected resource costs.
Destroy labs when finished to recover local resources.

## License

The repository is licensed under the [MIT License](LICENSE).

[course]: https://reece.ai/learn/enterprise-networking-for-systems-engineers
[lab-01-page]: https://reece.ai/labs/locate-the-failing-stage-of-a-connection
