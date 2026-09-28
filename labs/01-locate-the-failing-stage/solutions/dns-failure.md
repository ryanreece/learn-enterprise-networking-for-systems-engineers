# Solution: DNS Failure

> **Spoiler warning:** Use this guide only after collecting your own evidence.
> The normal exercise is to identify and repair the fault before reading the
> solution.

## Expected evidence

From the client, the original name does not resolve:

```bash
dig app.lab.test
dig @10.10.3.53 app.lab.test
```

The authoritative server still answers for another record, which shows that
the service itself is available:

```bash
dig @10.10.3.53 dns.lab.test
```

Holding the address constant lets the later stages complete:

```bash
nc -vz -w 3 10.10.2.10 443

curl --verbose \
  --resolve app.lab.test:443:10.10.2.10 \
  https://app.lab.test/
```

Together, those results locate the fault at name resolution rather than the
route, policy boundary, listener, certificate, or application.

## Root cause

The `app.lab.test` A record is missing from the runtime CoreDNS zone at
`.state/dns/db.lab.test`. CoreDNS remains healthy and authoritative for the
zone, so the missing name returns `NXDOMAIN`.

## Repair

Run these steps from the lab directory on the **host**:

1. Open `.state/dns/db.lab.test` in a text editor.
2. Add this record if it is absent:

   ```text
   app IN A 10.10.2.10
   ```

3. Increase the integer on the line marked `; serial`. CoreDNS uses that SOA
   serial to recognize the updated zone.
4. Save the file and allow up to one second for the reload.

Confirm the repaired record from the client:

```bash
make client
dig @10.10.3.53 app.lab.test
exit
```

Finally, repeat the original transaction from the host:

```bash
make verify
```

Do not use `curl --resolve` as repair evidence because it bypasses the failed
stage. If manual recovery is unsuccessful, `make reset` restores the complete
known-good state as an escape hatch.
