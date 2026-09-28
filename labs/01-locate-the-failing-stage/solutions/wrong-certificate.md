# Solution: Wrong Certificate

> **Spoiler warning:** Use this guide only after collecting your own evidence.
> The normal exercise is to identify and repair the fault before reading the
> solution.

## Expected evidence

From the client, DNS, route selection, and TCP/443 remain healthy:

```bash
dig app.lab.test
ip route get 10.10.2.10
nc -vz -w 3 app.lab.test 443
```

Inspect the certificate presented for the original connection:

```bash
openssl s_client \
  -connect app.lab.test:443 \
  -servername app.lab.test </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -ext subjectAltName
```

The certificate identifies `wrong.lab.test`, not `app.lab.test`. It is still
signed by the trusted lab CA, which can be tested without checking the
hostname:

```bash
openssl s_client \
  -connect app.lab.test:443 \
  -servername app.lab.test \
  -verify_return_error </dev/null
```

That command reports a successful chain verification. Adding the expected
hostname makes validation fail specifically with `hostname mismatch`:

```bash
openssl s_client \
  -connect app.lab.test:443 \
  -servername app.lab.test \
  -verify_hostname app.lab.test \
  -verify_return_error </dev/null
```

An insecure request can prove the application still responds, but it must not
be treated as proof of repair:

```bash
curl --insecure https://app.lab.test/
```

The expected body is `lab01-baseline-ok`.

## Root cause

NGINX is serving the lab-generated certificate for `wrong.lab.test`. The
certificate chains to the correct lab CA, TLS negotiation works, and the
application is healthy, but the certificate identity does not authorize
`app.lab.test`.

## Repair

From the lab directory on the **host**, copy the known-good certificate and
key into the active files, validate NGINX configuration, and reload it:

```bash
cp .state/certificates/valid-server.crt \
  .state/certificates/server.crt
cp .state/certificates/valid-server.key \
  .state/certificates/server.key

docker exec clab-lab01-web nginx -t
docker exec clab-lab01-web nginx -s reload
```

Then repeat the original transaction:

```bash
make verify
```

Do not add `--insecure` to the verification command or change the client's
trust settings. Those approaches suppress the evidence instead of repairing
the server identity. If manual recovery is unsuccessful, `make reset` restores
the complete known-good state as an escape hatch.
