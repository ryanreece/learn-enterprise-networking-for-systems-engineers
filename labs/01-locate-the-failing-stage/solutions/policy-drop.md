# Solution: Policy Drop

> **Spoiler warning:** Use this guide only after collecting your own evidence.
> The normal exercise is to identify and repair the fault before reading the
> solution.

## Expected evidence

From the client, DNS and route selection remain correct while TCP/443 times
out:

```bash
dig app.lab.test
ip route get 10.10.2.10
nc -vz -w 3 10.10.2.10 443
```

The name resolves to `10.10.2.10`, and the client selects `10.10.1.1` through
`eth1`. On the router, inspect the scenario-owned policy table:

```bash
make router
nft list table inet lab01
```

The forward chain contains a counter-bearing drop rule for the HTTPS flow.
Repeat the client TCP test, then list the table again. Its packet counter
increases.

To locate the boundary precisely, capture the flow on `eth1` and `eth2` in
separate router sessions:

```bash
tcpdump -ni eth1 'src host 10.10.1.10 and dst host 10.10.2.10 and tcp dst port 443'
tcpdump -ni eth2 'src host 10.10.1.10 and dst host 10.10.2.10 and tcp dst port 443'
```

After repeating the TCP test, SYN packets appear on the client-facing `eth1`
interface but not the application-facing `eth2` interface. The routes remain
correct, which distinguishes this failure from the return-route scenario.

The application is also healthy when tested locally. From the host, run:

```bash
make server
wget -q -O - --no-check-certificate https://127.0.0.1/
exit
```

The expected output is `lab01-baseline-ok`.

## Root cause

The router's `inet lab01` nftables table contains a silent drop rule matching
traffic from `10.10.1.10` to `10.10.2.10` on TCP/443. Routing is correct, but
the forward hook discards the SYN before it leaves the router's `eth2`
interface.

## Repair

The `lab01` table belongs only to this scenario, so remove that table from the
**router container**:

```bash
make router
nft delete table inet lab01
nft list ruleset
exit
```

Then repeat the original transaction from the host:

```bash
make verify
```

Do not flush the complete ruleset: unrelated Containerlab or Docker-managed
rules may exist in the namespace. If manual recovery is unsuccessful,
`make reset` removes the scenario table and restores the complete known-good
state as an escape hatch.
