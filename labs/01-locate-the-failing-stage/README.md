# Lab 01: Locate the Failing Stage of a Connection

## Lab outcome

Given a failed HTTPS transaction, you will identify the last working stage,
collect evidence at the failing boundary, repair the actual fault, and verify
the original transaction from name resolution through the application.

## Implementation status

This lab supplements [**The Network Model I Use to Troubleshoot
Everything**](/learn/enterprise-networking/network-model). The lesson supplies
the mental framework to understand network troubleshooting for systems
engineers and this lab puts the concepts into practice.

The investigation follows six stages:

1. Name resolution
2. Local delivery
3. Forward and return path
4. Policy and translation
5. TCP or UDP transport
6. TLS, authentication, and application

## Time, cost, level, and tested versions

| Attribute | Current value |
| --- | --- |
| Estimated time | Not yet measured on a clean learner walkthrough |
| Cost | No cloud cost; local compute, storage, and download usage only |
| Level | Foundational |
| Last-tested host | Ubuntu 24.04.5 LTS, Linux 6.17, x86_64 |
| Last-tested tools | Containerlab 0.79.0, Docker Engine 27.5.1, OpenSSL 3.0.13 |
| Service images | CoreDNS 1.14.7, NGINX 1.30.5 on Alpine 3.24 |
| Last baseline and scenario test | September 28, 2026 |

The known-good baseline and every named scenario passed on this reference
environment. The lab remains in development until challenge mode and a clean
learner walkthrough are complete.

## Prerequisites and supported platforms

Part A requires a hostname you own or are authorized to test. It makes no host
changes.

Part B requires native Linux, Docker Engine, Containerlab, Git, GNU Make, Bash,
OpenSSL, an OpenSSH client, and initial Internet access for packages and
images. Read the repository [environment requirements], [installation guide],
and [supported platforms] before attempting it.

## Part A — Observe a real connection

Only test a target you own or are explicitly authorized to test. These steps
observe state and send ordinary DNS, TCP, TLS, and HTTP requests. They must not
change DNS settings, routes, firewall policy, the hosts file, or certificate
trust.

### Record the flow first

Create a record before troubleshooting:

| Field | Your observation |
| --- | --- |
| Source host and address | |
| Destination hostname | |
| Resolved destination address | |
| Protocol and port | TCP/443 |
| Observation time and time zone | |
| Expected result | Validated TLS and the expected HTTPS response |

---

### Linux observations

Set `TARGET` to the authorized hostname you want to test:

```bash title="Linux Terminal"
export TARGET="reece.ai"

# Query the A record for the target and display the responding DNS server.
dig "$TARGET" A

# Save the first returned IPv4 address.
export ADDRESS="$(dig +short A "$TARGET" | head -n 1)"

# Confirm the values used by the remaining tests.
printf 'Target:  %s\nAddress: %s\n' "$TARGET" "$ADDRESS"
```

Observe various connection methods from your machine to the `$TARGET`:

```bash title="Linux Terminal"
# Record the current date and time, including the local UTC offset.
date -Is

# Show the addresses assigned to each local network interface.
ip -brief address

# Show the route, outgoing interface, next hop, and source address
# the local host would use to reach the selected destination address.
ip route get "$ADDRESS"

# Show cached IPv4 ARP and IPv6 neighbor-discovery entries.
# For an off-subnet destination, expect to see the local gateway rather
# than the destination server.
ip neighbor show

# Test whether a TCP connection can be established to the selected
# destination address on port 443. This bypasses another DNS lookup.
nc -vz -w 5 "$ADDRESS" 443

# Establish TCP and perform a TLS handshake with the selected address.
# -servername supplies the hostname through TLS SNI.
openssl s_client \
  -connect "${ADDRESS}:443" \
  -servername "$TARGET" \
  -verify_return_error \
  -showcerts \
  </dev/null

# Perform the complete application transaction:
# DNS resolution, TCP connection, TLS negotiation, and an HTTP request.
curl --verbose --connect-timeout 5 "https://${TARGET}/"
```

### Windows PowerShell observations

Run these in PowerShell against the same authorized target:

```powershell title="Widnows PowerShell"
$Target = 'reece.ai'

# Query the target's IPv4 records.
$DnsResult = Resolve-DnsName `
    -Name $Target `
    -Type A `
    -DnsOnly

# Select the first returned IPv4 address.
$Address = $DnsResult |
    Where-Object Type -eq 'A' |
    Select-Object -First 1 -ExpandProperty IPAddress

# Stop if DNS did not return an IPv4 address.
if (-not $Address) {
    throw "No IPv4 address was returned for $Target"
}

# Confirm the values used by the remaining tests.
Write-Host "Target:  $Target"
Write-Host "Address: $Address"
```

Observe various connection methods from your machine to the `$Target`:

```powershell title="Windows PowerShell"
# Record the current date and time, including the local UTC offset.
Get-Date -Format o

# Show the address, gateway, and DNS configuration assigned to each
# network interface. This does not necessarily show the public IP address.
Get-NetIPConfiguration

# Display the DNS results used to select the destination address.
$DnsResult

# Show the route, outgoing interface, next hop, and source address
# Windows would use to reach the selected destination address.
Find-NetRoute -RemoteIPAddress $Address

# Show cached IPv4 ARP entries.
# For an off-subnet destination, expect an entry for the local gateway
# rather than for the destination server.
Get-NetNeighbor -AddressFamily IPv4

# Test whether a TCP connection can be established directly to the
# selected destination address on port 443. Using the address avoids
# performing another DNS lookup.
Test-NetConnection `
    -ComputerName $Address `
    -Port 443 `
    -InformationLevel Detailed

# Test the selected address while preserving the hostname for TLS SNI,
# certificate validation, and the HTTP Host header.
curl.exe `
    --verbose `
    --connect-timeout 5 `
    --resolve "${Target}:443:${Address}" `
    "https://${Target}/"

# Perform the complete application transaction using normal resolution:
# DNS lookup, TCP connection, TLS negotiation, and an HTTP request.
curl.exe `
    --verbose `
    --connect-timeout 5 `
    "https://${Target}/"
```

### What the evidence proves

| Observation | What it supports | What it does not prove |
| --- | --- | --- |
| `dig` or `Resolve-DnsName` | DNS returned a particular answer at that time | That the address is reachable or serving the right application |
| Interface and neighbor state | Local addressing and currently known adjacent mappings | End-to-end routing or remote health |
| Route selection | The local kernel selected an egress path and next hop | That every forward and return hop works |
| TCP connection test | A TCP handshake to the selected name and port completed | Certificate identity or correct HTTP behavior |
| TLS output | The peer presented a certificate and TLS negotiation progressed | Correct application content unless identity and trust are also checked |
| `curl` without insecure options | DNS, TCP, certificate validation, TLS, and an HTTP exchange progressed | The internal health of every application dependency |

Save the flow record and identify the last stage for which you have positive
evidence. Avoid treating ping as proof of HTTPS health.

## Part B — Troubleshoot the isolated lab

The rest of this guide runs inside the deterministic Containerlab environment.
Unless a step explicitly says otherwise, run lifecycle and `make` commands
from the Lab 01 directory on the Linux host.

## Architecture and addressing

Part B uses only Linux containers and freely redistributable images. The
application will not use the host network or publish HTTPS outside the lab.

```mermaid
flowchart LR
    client["Client<br/>10.10.1.10<br/>10.10.3.10"] --> router["Router / firewall<br/>10.10.1.1 and 10.10.2.1"]
    router --> web["HTTPS application<br/>10.10.2.10"]
    client --> dns["DNS<br/>10.10.3.53"]
```

[`configs/lab.env`](configs/lab.env) is the executable source of truth for
names, images, and addresses. This table mirrors it for learners.

| Segment or name | Value | Purpose |
| --- | --- | --- |
| Client segment | `10.10.1.0/24` | Client-to-router link |
| Client, routed link | `10.10.1.10` | Origin of the HTTPS transaction |
| Router, client side | `10.10.1.1` | Application next hop and policy boundary |
| Application segment | `10.10.2.0/24` | Router-to-server link |
| Router, application side | `10.10.2.1` | Application-side gateway and observation point |
| HTTPS application | `10.10.2.10` | TLS and HTTP endpoint |
| DNS segment | `10.10.3.0/24` | Direct client-to-DNS link |
| Client, DNS link | `10.10.3.10` | Source of lab DNS queries |
| DNS | `10.10.3.53` | Lab-local authoritative resolver |
| Application name | `app.lab.test` | Original transaction hostname |
| Application service | TCP/443 | Original transaction transport |

The design must allow captures on both sides of the router so a learner can
prove whether a SYN left the client, crossed the policy boundary, reached the
server, and received a returning response.

## Environment validation

From the lab directory, run the read-only host check:

```bash
make check
```

It validates Linux, Docker access, Containerlab, OpenSSL, OpenSSH, Make, and
the host's forwarding sysctl interface. It does not deploy or change the lab.

## Deployment

From this lab directory, build the local images and deploy the topology:

```bash
make build
make deploy
```

Deployment generates a lab-only CA, a valid certificate for `app.lab.test`,
and a deliberately incorrect certificate for the TLS scenario. It also creates
an ephemeral SSH identity for the client. Private keys remain under the ignored
`.state/` directory. Deployment then creates the isolated topology, trusts the
lab-only CA inside the disposable client container, and applies the known-good
addresses and routes. It does not change the host's certificate trust store.

No application port is published on the host. Containerlab creates a private
management network named `lab01-mgmt`; the original HTTPS transaction uses
only the three data-plane links shown above.

## Known-good baseline

Run:

```bash
make baseline
```

The command proves, in order:

1. Router forwarding and the explicit HTTPS allow-list policy are active.
2. The selected route crosses the router/firewall.
3. `app.lab.test` resolves to `10.10.2.10`.
4. TCP/443 completes.
5. TLS presents the expected identity and validates against the lab CA.
6. HTTPS returns the expected application response.
7. The router's HTTPS allow-rule counter records the verified flow.

Save this evidence before activating any future scenario. You can repeat the
original transaction at any time with `make verify`.

## Enter the lab nodes and test the six stages

The lab provides short host-side commands for each node you need to inspect:

| Command | Destination | Access method |
| --- | --- | --- |
| `make client` | Diagnostic client | Key-authenticated SSH |
| `make router` | Router/firewall | Interactive container shell |
| `make server` | HTTPS application server | Interactive container shell |

Run these commands from separate host terminals when you need simultaneous
captures or connection tests. Type `exit` to leave any node shell.

### Enter the client

Open an SSH session from the **host terminal**:

```bash
make client
```

The helper uses the generated key and connects to the client's fixed
management address, `172.31.1.10`. The equivalent command is:

```bash
ssh -i .state/ssh/id_ed25519 \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile=.state/ssh/known_hosts \
  root@172.31.1.10
```

The prompt that opens is the **client container**. Run the following checks
there. Type `exit` to return to the host. These are observations, not a script:
record what each command proves and stop where the evidence stops.

The login banner summarizes the original transaction and a short set of useful
commands. Run `help` at any time to display it again. Use `help diagram` to
print the lab topology or `lab addresses` to print its address table.

### Stage 1 — Name resolution

```bash
dig app.lab.test
dig @10.10.3.53 app.lab.test
```

The first query exercises the client's configured resolver; the second asks
the lab DNS service explicitly. An answer proves only that DNS returned an
address, not that the application is reachable.

### Stage 2 — Local delivery

```bash
ip -brief address
ip neighbor show
ip route get 10.10.3.53
```

These show local interfaces, learned neighbor mappings, and how the directly
connected DNS address will be reached. They do not prove the routed application
path.

### Stage 3 — Forward and return path

```bash
ip route get 10.10.2.10
traceroute -n -T -p 443 10.10.2.10
```

The route lookup should select `10.10.1.1` on `eth1`; TCP traceroute should
show the router and application. A route existing locally does not prove the
return path works.

### Stage 4 — Policy and translation

On the **client**, observe the target flow while repeating a connection test
in a second client session:

```bash
tcpdump -ni eth1 'host 10.10.2.10 and tcp port 443'
```

Policy lives at the router boundary, so client evidence alone cannot prove
what the router accepted, dropped, or translated. From a second **host
terminal**, enter the router:

```bash
make router
```

Then inspect policy and connection tracking inside the **router container**:

```bash
nft list table inet lab01
nft list ruleset
conntrack -L -p tcp
tcpdump -ni eth1 'host 10.10.2.10 and tcp port 443'
tcpdump -ni eth2 'host 10.10.1.10 and tcp port 443'
```

The known-good `inet lab01` table has a default-drop forward chain, an
established/related return rule, and a counter-bearing rule that explicitly
permits the client-to-application TCP/443 flow. Repeating the client connection
test increases those counters.

Compare the client-side and application-side interfaces. Stop each capture
with Ctrl-C and type `exit` to return to the host.

### Stage 5 — TCP transport

Back in the **client container**, run:

```bash
nc -vz -w 3 10.10.2.10 443
ss -tn
```

A successful connection proves that TCP/443 completed. It does not prove TLS
identity, trust, or the expected application response.

### Stage 6 — TLS and application

```bash
openssl s_client \
  -connect 10.10.2.10:443 \
  -servername app.lab.test \
  -verify_hostname app.lab.test \
  -verify_return_error </dev/null

curl --verbose https://app.lab.test/
```

OpenSSL explicitly checks the expected name and lab trust chain through the
client's system trust store. Curl repeats the original transaction, including
DNS, TCP, TLS validation, and HTTP.

When DNS is suspect, this **diagnostic bypass** holds the destination address
constant while retaining the correct TLS name:

```bash
curl --verbose \
  --resolve app.lab.test:443:10.10.2.10 \
  https://app.lab.test/
```

That result can isolate DNS from later stages, but it is not proof of repair.
`make verify` deliberately does not bypass DNS.

## Tasks and checkpoints

For each scenario:

1. Define the original flow.
2. Reproduce the learner-visible symptom.
3. Test the six stages in order until evidence stops.
4. Observe both sides of the last successful boundary.
5. State the root cause and the evidence that distinguishes it.
6. Repair the actual state without using `reset`.
7. Run `make verify` to repeat the original HTTPS transaction.

## Break and troubleshoot scenarios

The following scenarios are deterministic, idempotent, reversible, and
available. From the **host terminal**, activate one implemented scenario:

### DNS Failure

Name resolution fails while the later stages remain healthy.

```bash title="Linux Terminal"
make scenario SCENARIO=dns-failure
```

### Local Delivery Failure

The client cannot resolve the configured next hop, so no HTTPS packet leaves
it.

```bash title="Linux Terminal"
make scenario SCENARIO=local-delivery
```

### Return Route Failure

The client cannot resolve the configured next hop, so no HTTPS packet leaves it.
```bash title="Linux Terminal"
make scenario SCENARIO=return-route
```

### Policy Drop Failure

Correctly routed HTTPS traffic is silently dropped at the policy boundary.

```bash title="Linux Terminal"
make scenario SCENARIO=policy-drop
```

### Transport Failure

The application host rejects TCP/443 because no HTTPS listener is running.

```bash title="Linux Terminal"
make scenario SCENARIO=transport-failure
```

### Wrong Certificate Failure

TCP succeeds, but certificate validation for `app.lab.test` fails.

```bash title="Linux Terminal"
make scenario SCENARIO=wrong-certificate
```

### Application Failure

DNS through TLS succeed, but HTTPS returns status 500.

```bash title="Linux Terminal"
make scenario SCENARIO=application-failure
```

Normal learner output will describe only the symptom and task. Mutation detail
is reserved for ignored instructor/debug state. Enter the client, work through
the six stages, repair the identified state, and run `make verify` from the
host.

### Challenge mode

After proving the known-good baseline, ask the lab to select one of the seven
failures without revealing its identity:

```bash
make challenge
make status
```

`make challenge` first restores and verifies the baseline, randomly applies one
supported failure, and prints only the common symptom and troubleshooting task.
`make status` reports topology and node state without naming the failure.

Work through the same six stages, repair the actual state, and run
`make verify`. The active marker records only `challenge`. Do not inspect
`.state/scenario-debug.log`, `.state/challenge-apply.log`, or the solution
documents during the exercise: those are instructor and maintainer artifacts
that can disclose the answer. `make reset` remains the recovery escape hatch if
you cannot complete a manual repair.

CoreDNS reads its runtime zone from `.state/dns/db.lab.test` on the host and
reloads it when its SOA serial increases. The application container's route to
the client subnet can be inspected with `docker exec clab-lab01-web ip route`.
The client's selected next hop and neighbor state can be inspected with
`ip route get 10.10.2.10` and `ip neighbor` after running `make client`. Router
policy can be inspected with `make router` and `nft list ruleset`. The HTTPS
service process and configuration can be inspected after running `make server`.
The rendered active and known-good application configurations are
`.state/web/nginx.conf` and `.state/web/baseline-nginx.conf` on the host. Use
`openssl s_client` from the client to inspect the presented TLS identity. Use
these only after evidence identifies the relevant stage. `make reset` restores
and verifies the baseline if you need an escape hatch; it is not the normal
learner repair.

Maintainers can exercise deployment, two consecutive applications of each
scenario, every eligible hidden challenge, a random challenge, failure
assertions, reset, verification, and teardown with:

```bash
make test
```

The test always tears down its topology, including after a failed assertion.

## Scenario solutions

The solution guides contain spoilers and exact repair steps. Use them after
completing an investigation or when reviewing collected evidence:

- [DNS failure solution](solutions/dns-failure.md)
- [Local-delivery solution](solutions/local-delivery.md)
- [Return-route solution](solutions/return-route.md)
- [Policy-drop solution](solutions/policy-drop.md)
- [Transport-failure solution](solutions/transport-failure.md)
- [Wrong-certificate solution](solutions/wrong-certificate.md)
- [Application-failure solution](solutions/application-failure.md)

Every scenario currently eligible for challenge mode has a corresponding
solution document.

## Verification

The command:

```bash
make verify
```

verifies the original DNS and HTTPS transaction without repairing it. A pass
requires the expected DNS answer, TCP/443, a trusted certificate with the
expected identity, and the exact application response. Ping, an open port
alone, or an arbitrary HTTP response does not count as repair evidence.

## Teardown and cost control

Run `make destroy` when finished. It removes only the `lab01` topology, its
Containerlab directory, and locally generated `.state/` files. It is safe to
repeat after a partial deployment. No public cloud resources are created. Do
not use broad Docker cleanup commands on a shared host.

## Troubleshooting the lab environment

Use the repository's [environment troubleshooting guide] for Docker,
Containerlab, image, permission, or host-kernel problems. Keep those separate
from the deliberate in-lab faults that form the exercise.

## Related lesson and source links

- [The Network Model I Use to Troubleshoot Everything][network model lesson]
- [Enterprise Networking for Systems Engineers course][course]
- [Locate the Failing Stage of a Connection lab page][lab page]
- [Containerlab documentation]
- [Repository root](../..)

[Containerlab documentation]: https://containerlab.dev/
[course]: https://reece.ai/learn/enterprise-networking-for-systems-engineers
[environment requirements]: ../../docs/environment-requirements.md
[environment troubleshooting guide]: ../../docs/troubleshooting-the-lab-environment.md
[installation guide]: ../../docs/installing-containerlab.md
[lab page]: https://reece.ai/labs/locate-the-failing-stage-of-a-connection
[network model lesson]: http://localhost:3000/learn/enterprise-networking/network-model
[supported platforms]: ../../docs/supported-platforms.md
