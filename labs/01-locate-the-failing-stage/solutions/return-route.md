# Solution: Return-Route Failure

> **Spoiler warning:** Use this guide only after collecting your own evidence.
> The normal exercise is to identify and repair the fault before reading the
> solution.

## Expected evidence

DNS and the client's forward route remain correct:

```bash
dig app.lab.test
ip route get 10.10.2.10
```

The name resolves to `10.10.2.10`, and the client selects `10.10.1.1` through
`eth1`. TCP does not complete:

```bash
nc -vz -w 3 10.10.2.10 443
```

Capture the flow on the router's application-facing interface from a **host
terminal**:

```bash
docker exec -it clab-lab01-router \
  tcpdump -ni eth2 'host 10.10.1.10 and host 10.10.2.10 and tcp port 443'
```

Repeat the TCP test from the client while the capture runs. Client SYN packets
cross the router toward the application, but no SYN-ACK returns through that
interface. This distinguishes the failure from a missing client route or a
forward-policy drop at the router.

The application itself remains healthy when tested locally:

```bash
docker exec clab-lab01-web \
  wget -q -O - --no-check-certificate https://127.0.0.1/
```

The expected output is `lab01-baseline-ok`.

## Root cause

The application container has a blackhole route for the client subnet instead
of its known-good route through the router:

```bash
docker exec clab-lab01-web ip route show exact 10.10.1.0/24
```

The request reaches the application, but the kernel discards traffic returning
to `10.10.1.0/24`. The TCP handshake therefore cannot complete.

## Repair

Replace the incorrect route from the lab directory on the **host**:

```bash
docker exec clab-lab01-web \
  ip route replace 10.10.1.0/24 via 10.10.2.1
```

Confirm the route:

```bash
docker exec clab-lab01-web ip route show exact 10.10.1.0/24
```

It should report `10.10.1.0/24 via 10.10.2.1 dev eth1`. Then repeat the
original transaction:

```bash
make verify
```

If manual recovery is unsuccessful, `make reset` restores the complete
known-good state as an escape hatch.
