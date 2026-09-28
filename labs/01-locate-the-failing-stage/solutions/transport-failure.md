# Solution: Transport Failure

> **Spoiler warning:** Use this guide only after collecting your own evidence.
> The normal exercise is to identify and repair the fault before reading the
> solution.

## Expected evidence

Enter the client from the lab directory on the **host**:

```bash
make client
```

DNS and route selection still return their known-good results:

```bash
dig app.lab.test
ip route get 10.10.2.10
traceroute -n -T -p 443 10.10.2.10
```

The name resolves to `10.10.2.10`, and the route uses `10.10.1.1` on `eth1`.
The TCP connection itself is refused:

```bash
nc -vz -w 3 10.10.2.10 443
```

To distinguish a closed listener from a silent policy drop, leave the client
session open and enter the router from a second **host terminal**:

```bash
make router
tcpdump -ni eth2 'host 10.10.1.10 and host 10.10.2.10 and tcp port 443'
```

Repeat the `nc` command from the client. The router capture shows the client
SYN reaching the application segment and an immediate RST returning from
`10.10.2.10:443`. A policy drop would not produce that rejection from the
application host.

The server node and NGINX configuration remain available for inspection. From
another **host terminal**, enter the server:

```bash
make server
nginx -t
test -s /tmp/nginx.pid && kill -0 "$(cat /tmp/nginx.pid)"
echo "$?"
```

The configuration test succeeds, but the process check returns a nonzero
status because the NGINX master process is not running.

## Root cause

The NGINX service was stopped, leaving no process listening on TCP/443. The web
container remains running so its addressing, return route, configuration, and
process state can still be inspected. The application host's TCP stack rejects
the SYN because nothing owns the destination port.

## Repair

From the existing **server-container** shell, start NGINX and confirm its
configuration remains valid:

```bash
nginx
nginx -t
exit
```

Then repeat the original transaction from the **host**:

```bash
make verify
```

`nginx -s reload` is not sufficient when no master process is running; start
the service with `nginx`. Do not add a firewall rule or change the client route,
because the SYN already reaches the correct host and receives a response. If
manual recovery is unsuccessful, `make reset` restarts the service and restores
the complete known-good state as an escape hatch.
