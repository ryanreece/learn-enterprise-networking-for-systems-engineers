# Learn Enterprise Networking for Systems Engineers

## Project purpose

Build the hands-on lab repository for the Reece.AI course **Enterprise Networking for Systems Engineers**.

The repository should teach enterprise networking through reproducible environments and evidence-driven troubleshooting. Each lab must reinforce the Reece.AI teaching method:

1. Explain the architecture and expected behavior.
2. Build or deploy a working baseline.
3. Break one or more components intentionally.
4. Troubleshoot from symptom to evidence to root cause.
5. Verify the repair using the original transaction.

The Reece.AI website is the canonical teaching and curriculum interface. This repository contains executable topologies, configurations, scripts, validation, and standalone lab instructions. Do not duplicate an entire lesson inside a lab README.

## Repository scope

Use one repository for this course rather than one repository per lab or one monorepo for all Reece.AI courses.

The working repository name is:

```text
learn-enterprise-networking-for-systems-engineers
```

The repository should eventually contain all labs associated with the Enterprise Networking for Systems Engineers course. Shared container images, scripts, conventions, and documentation should be reused across labs.

Do not implement labs from other Reece.AI courses here.

## Required lab platform

Containerlab is the standard environment for all isolated course labs, beginning with Lab 01.

Use Containerlab even when a lab could be implemented with Docker Compose alone. Later lessons will use larger topologies, routing protocols, VRFs, firewalls, and network operating systems. Learners should become familiar with the Containerlab workflow from the beginning.

The first lab has two parts:

- **Part A — Observe a real connection:** Runs directly from the learner's computer and requires no Containerlab deployment.
- **Part B — Troubleshoot an isolated network:** Uses a deterministic Containerlab topology controlled by this repository.

Part A provides the low-friction entry point. Part B is the canonical, reproducible lab.

Do not create CML, EVE-NG, CloudFormation, or Terraform alternatives unless a future task explicitly asks for one. Those may be added later as platform-specific or advanced labs, but they are not part of the initial repository build.

## Supported hosts

Treat native Linux as the reference platform for Containerlab labs.

- Document and test a current Ubuntu LTS installation first.
- Rocky Linux support is desirable where it does not complicate the implementation.
- macOS and Windows users should run Part B in a Linux virtual machine unless a workflow has been tested and documented for their platform.
- WSL2 may be documented as best effort only after it has been tested end to end.
- Part A should include both Linux shell and Windows PowerShell commands because it runs on the learner's own computer.

Never imply that Containerlab runs natively on every desktop operating system.

## Initial repository layout

Use the following structure unless implementation evidence justifies a small change:

```text
.
├── AGENTS.md
├── README.md
├── LICENSE
├── Makefile
├── .gitignore
├── .editorconfig
├── .github/
│   └── workflows/
│       └── validate.yml
├── docs/
│   ├── environment-requirements.md
│   ├── installing-containerlab.md
│   ├── supported-platforms.md
│   └── troubleshooting-the-lab-environment.md
├── shared/
│   ├── images/
│   │   ├── network-toolbox/
│   │   │   └── Dockerfile
│   │   └── linux-router/
│   │       └── Dockerfile
│   └── scripts/
│       └── common.sh
└── labs/
    └── 01-locate-the-failing-stage/
        ├── README.md
        ├── Makefile
        ├── topology.clab.yml
        ├── configs/
        │   ├── dns/
        │   ├── router/
        │   ├── web/
        │   └── certificates/
        ├── scripts/
        │   ├── check-prerequisites.sh
        │   ├── deploy.sh
        │   ├── baseline.sh
        │   ├── status.sh
        │   ├── verify.sh
        │   ├── reset.sh
        │   ├── destroy.sh
        │   └── scenario.sh
        ├── scenarios/
        │   ├── dns-failure.sh
        │   ├── return-route.sh
        │   ├── policy-drop.sh
        │   └── wrong-certificate.sh
        ├── tests/
        │   └── test-lab.sh
        └── solutions/
            └── instructor-notes.md
```

Do not create empty directories or placeholder files for future labs. Add a new lab directory only when implementing that lab.

## Root repository experience

The root `README.md` should:

- Explain the course and the purpose of the repository.
- Link to the Reece.AI course and lab pages using configurable or clearly marked URLs.
- State that native Linux is the reference platform.
- Describe the common Containerlab lifecycle.
- List implemented labs and their status.
- Link to installation, supported-platform, and troubleshooting documentation.
- Avoid repeating every step from each lab README.

The root `Makefile` should provide a discoverable interface for common operations. At minimum:

```text
make help
make check
make build
make lint
make test
```

Lab-specific lifecycle commands belong in each lab's Makefile.

## Lab 01 objective

The first lab is **Locate the Failing Stage of a Connection**.

It supports the lesson **The Network Model I Use to Troubleshoot Everything** and teaches the learner to locate a failure within six diagnostic stages:

1. Name resolution
2. Local delivery
3. Forward and return path
4. Policy and translation
5. TCP or UDP transport
6. TLS, authentication, and application

The learner should define the flow, establish a known-good baseline, activate a controlled failure, identify the last working stage, repair the problem, and verify the original HTTPS transaction.

## Lab 01 topology

Build the first topology entirely from Linux containers and freely redistributable images. Do not require licensed network operating system images.

The logical topology must contain:

- A client with `dig`, `curl`, `iproute2`, `traceroute`, `netcat`, `openssl`, and `tcpdump`.
- An authoritative or lab-local DNS service.
- A Linux router/firewall with IP forwarding, routing, nftables, connection tracking, and packet-capture tools.
- An HTTPS application endpoint.
- A small lab certificate authority or generated lab certificates, including a valid server certificate and a deliberately incorrect certificate.

The logical traffic path should be:

```text
client -> router/firewall -> HTTPS application
   |
   +-> DNS service
```

Use deterministic private addresses and document them in one location. Avoid scattering addresses across unrelated scripts. Prefer a shared environment/configuration file or clearly named shell constants consumed by the topology, scripts, and tests.

The topology must allow observation at both sides of the routing and policy boundary. It must be possible to prove whether a SYN left the client, reached the router, reached the server, and whether the response returned.

Do not use the host network for the lab. Do not expose the HTTPS service publicly. Keep all failure scenarios inside the isolated topology.

## Container images

Prefer small, purpose-built images over installing packages every time the topology starts.

Create reusable images only when they provide course-wide value:

- `network-toolbox`: Diagnostic client with the networking tools used throughout the course.
- `linux-router`: IP forwarding, iproute2, nftables, conntrack, tcpdump, and the minimum supporting packages.

Use upstream images for well-defined services such as CoreDNS and NGINX when practical.

Requirements:

- Pin image versions. Do not use floating `latest` tags.
- Keep Dockerfiles small and readable.
- Add OCI labels describing the project and source repository.
- Minimize Linux capabilities, but grant the capabilities genuinely required for routing, firewalling, and packet capture.
- Do not bake secrets or private certificates into public images.
- Generate lab-only certificates from repository scripts or committed non-sensitive fixtures.

Do not publish images or create external infrastructure unless the user explicitly asks. Local image builds are sufficient for the initial implementation.

## Learner command interface

Expose a consistent Make-based interface. A learner should not need to understand container names or long `containerlab` commands to operate the lab.

Lab 01 must support:

```text
make help
make check
make build
make deploy
make baseline
make status
make scenario SCENARIO=dns-failure
make challenge
make verify
make reset
make destroy
make test
```

Expected behavior:

- `check`: Validate Containerlab, Docker, required kernel behavior, permissions, ports, and local dependencies without changing the lab.
- `build`: Build locally maintained container images.
- `deploy`: Create the topology and apply the known-good configuration.
- `baseline`: Run non-destructive checks proving the complete HTTPS transaction works.
- `status`: Show node and topology state without revealing the active failure's root cause.
- `scenario`: Activate one named failure idempotently.
- `challenge`: Select a supported failure without revealing which one was applied.
- `verify`: Test the original DNS and HTTPS transaction and report pass/fail without automatically repairing it.
- `reset`: Restore every node and configuration to the known-good deployed state without requiring a complete teardown when practical.
- `destroy`: Remove the topology and generated lab state safely.
- `test`: Exercise deploy, baseline, every scenario, reset, verification, and destroy.

Make targets should call scripts rather than contain large blocks of shell code.

## Part A requirements

Part A runs against a hostname the learner controls or is authorized to test. It should not change the learner's machine.

Document:

- A flow record containing source, destination hostname, resolved address, protocol, port, time, and expected result.
- Linux commands for DNS, interface state, neighbor state, route selection, TCP, TLS, and HTTP.
- Windows PowerShell equivalents where reasonably available.
- What each command proves and what it does not prove.
- A warning to run tests only against authorized targets.

Optional helper scripts may collect baseline information, but the README must also show the individual commands. Do not make the script a black box.

Do not modify the host's DNS settings, routing table, firewall, hosts file, or certificate trust store for Part A.

## Failure scenario contract

Every failure scenario must be deterministic, idempotent, reversible, and testable.

Each scenario script must support or be paired with logic for:

- Applying the failure from a known-good baseline.
- Confirming that the intended mutation occurred.
- Producing the expected learner-visible symptom.
- Restoring the known-good configuration.
- Avoiding unrelated changes to the topology.

The learner-facing output should describe the symptom and the task, not disclose the root cause.

Good learner-facing output:

```text
Scenario activated.

Observed symptom:
  The client cannot complete an HTTPS connection to app.lab.test.

Your task:
  1. Identify the last working stage.
  2. Collect evidence for the failing stage.
  3. Repair the environment.
  4. Run make verify.
```

Do not print the command that created the fault or a message such as `removed the return route` in normal learner mode. Detailed mutation information may be written to an instructor/debug log outside the normal output.

## Initial Lab 01 scenarios

Implement these four scenarios first:

### DNS failure

Change or remove the lab DNS record so the name fails to resolve or resolves to the wrong lab address.

The learner should use DNS evidence before investigating routing or policy.

### Return-route failure

Remove or alter the return route on the server side or an appropriate routing node.

The client should transmit traffic, but the return traffic should not reach it. The topology must allow captures that demonstrate the asymmetry.

### Policy drop

Apply a silent nftables drop for the target HTTPS flow at the router/firewall.

Routing must remain correct. Counters and captures should allow the learner to distinguish policy from missing routing once they inspect the boundary.

### Wrong TLS certificate

Configure the HTTPS service to present a certificate that does not match `app.lab.test` or the expected lab trust chain.

TCP must complete successfully. The failure must occur during certificate validation or TLS/application handling.

Do not start by implementing every possible failure. Closed listener, incorrect local prefix, application HTTP 500, NAT, and other scenarios may be added after the four core scenarios work end to end.

## Scenario repair model

The learner should repair the actual lab state whenever the fix is reasonable and safe. The lab README should provide enough operational context to inspect the relevant node without exposing the answer.

After the learner repairs the state:

```text
make verify
```

must test the original transaction:

1. `app.lab.test` resolves to the expected address.
2. The client can establish TCP/443.
3. TLS presents the expected certificate and validates against the lab trust chain.
4. The HTTPS request returns the expected application response.

Verification must not treat ping alone, TCP alone, or a generic HTTP response as proof that the lab is fixed.

`make reset` is an escape hatch that restores the baseline. It should not be presented as the normal learner repair method.

## Lab documentation template

Each lab README should follow this structure:

1. Lab title and outcome
2. Relationship to the Reece.AI lesson
3. Time, cost, level, and last-tested version
4. Prerequisites and supported platforms
5. Architecture and addressing table
6. Part A or pre-lab observation, when applicable
7. Environment validation
8. Deployment
9. Known-good baseline
10. Tasks and checkpoints
11. Break and troubleshoot scenarios
12. Verification
13. Teardown and cost control
14. Troubleshooting the lab environment
15. Related lesson and source links

Keep instructions explicit about which terminal commands run on the host and which run inside a lab node.

Use architecture diagrams where they materially clarify traffic flow. Store editable diagram source where possible. Mermaid is preferred for diagrams that also appear on Reece.AI.

## Script standards

Use Bash for Linux lifecycle and scenario scripts.

- Start scripts with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Resolve paths relative to the script or repository, not the caller's working directory.
- Quote variables.
- Use functions for repeated behavior.
- Emit short, actionable errors.
- Check dependencies before performing mutations.
- Make cleanup safe when the topology is partially deployed.
- Avoid destructive wildcard operations and broad recursive deletion.
- Do not use `sudo` inside scripts unless the operation genuinely requires it; document the permission requirement instead.
- Run ShellCheck and format consistently.

PowerShell is permitted only for Part A host-side examples or helpers. Do not maintain a second implementation of the Containerlab lifecycle in PowerShell.

## Configuration standards

- Keep the working baseline configuration separate from scenario mutations.
- Treat the baseline as declarative and repeatable.
- Keep scenario scripts narrowly scoped to one failure.
- Centralize topology names, addresses, DNS names, ports, and certificate names.
- Use `app.lab.test` as the default application hostname unless a better lab-local name is documented.
- Never depend on public DNS or internet access after required container images have been obtained.
- Do not use production-looking credentials or private address data from real environments.
- Add comments for non-obvious routing, nftables, and TLS configuration.

## Testing requirements

The lab is not complete until it has been executed end to end.

Automated tests must cover:

1. Prerequisite checks in a supported environment.
2. Image builds.
3. Topology deployment.
4. Known-good DNS, route, TCP, TLS, and HTTPS behavior.
5. Each scenario producing its intended failure.
6. Each scenario not breaking unrelated stages unexpectedly.
7. Reset returning the topology to the known-good state.
8. Teardown succeeding even after a failed or partial test.

Tests should distinguish the expected failure mode. For example, the TLS scenario must prove that TCP succeeds while certificate validation fails.

Pin the tested Containerlab version and record it in the lab README. When upgrading dependencies, rerun every scenario.

## Continuous integration

Create a GitHub Actions workflow that initially performs static validation:

- ShellCheck
- Dockerfile linting
- YAML validation
- Markdown link or style checks where useful
- Containerlab topology syntax validation if it can run without deploying

Add an end-to-end Containerlab job only after it is proven reliable on the selected runner. If privileged execution or runner networking makes the test unreliable, document the limitation and keep end-to-end testing available through `make test` for a Linux development host.

Do not make CI appear authoritative if it does not actually deploy and exercise the topology.

## Versioning and reproducibility

- Pin Containerlab and container image versions used for a tested lab release.
- Prefer tagged repository releases once a lab is published.
- Record the last-tested date and versions in each lab README.
- Keep generated runtime state out of Git.
- Commit configuration and certificate-generation inputs needed to recreate the lab.
- Do not commit packet captures unless they are intentional teaching fixtures and contain no sensitive information.

## Security and safety

- Keep test traffic inside the lab topology except for Part A's explicitly authorized target.
- Never introduce scripts that scan arbitrary public address ranges.
- Do not store real credentials, API keys, private keys, or production certificates.
- Lab private keys may be generated locally and ignored by Git.
- Bind no service to all host interfaces unless the lab requires it and the documentation explains why.
- Minimize container privileges and capabilities while preserving required networking behavior.
- Warn before any operation that changes host networking outside Containerlab-managed resources.
- Teardown must target only this lab's named topology and generated state.

## Content boundaries

The repository and website serve different purposes:

- Reece.AI `/learn/...` explains concepts and mental models.
- Reece.AI `/labs/...` presents the learner journey, requirements, architecture, and lab steps.
- This repository supplies the executable topology, configuration, scripts, tests, and standalone operational README.

Repository documentation should be usable without the website, but avoid copying the full conceptual lesson into GitHub. Link back to the relevant lesson for deeper explanation.

Do not edit the Reece.AI website from this repository unless the task explicitly includes both projects.

## Implementation order

When starting from an empty repository, work in this order:

1. Create the root structure, root README, editor configuration, ignore rules, and Make help/check targets.
2. Add environment and Containerlab installation documentation.
3. Create the Lab 01 directory and its README skeleton.
4. Build the reusable network-toolbox and Linux-router images.
5. Implement the Lab 01 known-good topology.
6. Add deterministic addressing, DNS, HTTPS, and certificate generation.
7. Implement baseline validation and complete end-to-end verification.
8. Implement one scenario at a time, including automated failure assertions and reset behavior.
9. Add challenge mode only after all named scenarios are stable.
10. Add static CI and then evaluate end-to-end CI.
11. Update last-tested versions and remove all placeholder language before calling the lab published.

Do not scaffold every future lab before Lab 01 works end to end.

## Definition of done for Lab 01

Lab 01 is complete when:

- A new learner can identify the supported environment and prerequisites.
- `make check` explains any missing dependency clearly.
- `make build && make deploy && make baseline` produces a verified working topology.
- Part A can be followed without modifying the learner's computer.
- Each of the four scenarios produces the intended symptom deterministically.
- The learner can collect meaningful evidence from the client, router/firewall, DNS service, and HTTPS server.
- `make verify` validates the original DNS and HTTPS transaction.
- `make reset` restores the baseline after every scenario.
- `make test` exercises the full lifecycle.
- `make destroy` removes only this lab's resources and succeeds from partial states.
- The README has been followed on a clean supported Linux host.
- No public cloud account, licensed image, or public test endpoint is required for Part B.
- Documentation no longer labels the lab as an untested stub.

## Working behavior for coding agents

Before changing code:

1. Read this file and the nearest lab README.
2. Inspect the current repository state and preserve unrelated user changes.
3. State the specific slice being implemented.

While working:

- Prefer a small, executable vertical slice over broad scaffolding.
- Keep the known-good topology working after each change.
- Test scripts and configurations rather than assuming they work.
- Use Conventional Commits and commit each coherent code or documentation
  change after it has been validated.
- Report environmental limitations honestly.
- Do not publish images, create cloud resources, or push repository changes unless explicitly requested.

When handing work back:

- Lead with what now works.
- List the validation commands that were run and their results.
- Identify anything not tested and why.
- Point to the next smallest implementation step.
