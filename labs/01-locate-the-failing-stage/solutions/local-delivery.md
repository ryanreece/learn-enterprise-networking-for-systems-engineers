# Solution: Local-Delivery Failure

> **Spoiler warning:** Use this guide only after collecting your own evidence.
> The normal exercise is to identify and repair the fault before reading the
> solution.

## Expected evidence

Enter the client from the lab directory on the **host**:

```bash
make client
```

Name resolution still returns the expected application address:

```bash
dig app.lab.test
```

The selected route instead identifies an unexpected next hop:

```bash
ip route get 10.10.2.10
```

The route uses `10.10.1.254` on `eth1`, not the known-good router at
`10.10.1.1`. A transport test times out because the client cannot deliver the
packet to that next hop:

```bash
nc -vz -w 3 10.10.2.10 443
ip neighbor show 10.10.1.254 dev eth1
```

The neighbor entry becomes `INCOMPLETE` or `FAILED`. To observe the boundary
directly, start a capture in one client session:

```bash
tcpdump -ni eth1 'arp or (host 10.10.2.10 and tcp port 443)'
```

Repeat the `nc` command in a second client session. The capture shows ARP
requests for `10.10.1.254`, but no TCP SYN for `10.10.2.10` leaves the client.
This locates the failure at local next-hop delivery, before the forward path or
router policy boundary.

## Root cause

The client's route for `10.10.2.0/24` points to the unused address
`10.10.1.254`. The client must resolve a next-hop link-layer address before it
can transmit the routed HTTPS packet, and no node owns that address.

## Repair

Inside the **client container**, replace the route with the known-good router:

```bash
ip route replace 10.10.2.0/24 via 10.10.1.1 dev eth1
ip route get 10.10.2.10
exit
```

The route lookup should now report `via 10.10.1.1 dev eth1`. From the **host**,
repeat the original transaction:

```bash
make verify
```

Deleting the failed neighbor entry is unnecessary because the repaired route no
longer selects it. Do not add a static neighbor entry for the unused address;
that would conceal the route error rather than repair it. If manual recovery is
unsuccessful, `make reset` restores the complete known-good state as an escape
hatch.
