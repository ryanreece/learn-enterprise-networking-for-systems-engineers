# Solution: Application Failure

> **Spoiler warning:** Use this guide only after collecting your own evidence.
> The normal exercise is to identify and repair the fault before reading the
> solution.

## Expected evidence

Enter the client from the lab directory on the **host**:

```bash
make client
```

DNS, route selection, and TCP/443 retain their known-good behavior:

```bash
dig app.lab.test
ip route get 10.10.2.10
nc -vz -w 3 app.lab.test 443
```

Certificate identity and trust validation also succeed:

```bash
openssl s_client \
  -connect app.lab.test:443 \
  -servername app.lab.test \
  -CAfile /etc/lab/ca.crt \
  -verify_hostname app.lab.test \
  -verify_return_error </dev/null
```

Inspect the complete HTTPS result without suppressing error responses:

```bash
curl --silent \
  --show-error \
  --cacert /etc/lab/ca.crt \
  --write-out '\nHTTP %{http_code}\n' \
  https://app.lab.test/
```

The request returns the body `lab01-application-error` and HTTP status `500`.
Because DNS, TCP, certificate identity, trust, and TLS all succeeded, this
locates the failure at the application stage rather than an earlier network
boundary.

From the **host**, compare the active NGINX configuration with its rendered
known-good version:

```bash
diff -u \
  .state/web/baseline-nginx.conf \
  .state/web/nginx.conf
```

The active `/` location returns status 500 and the deterministic error body
instead of the expected status 200 response.

## Root cause

The active NGINX application configuration deliberately returns HTTP 500 for
the original request. NGINX remains healthy and listening, and its certificate
remains valid, so transport and TLS complete before the application reports the
failure.

## Repair

From the lab directory on the **host**, copy the rendered known-good
configuration over the active bind-mounted file:

```bash
cp -- \
  .state/web/baseline-nginx.conf \
  .state/web/nginx.conf
```

Enter the **server container**, validate the repaired configuration, and reload
NGINX:

```bash
make server
nginx -t
nginx -s reload
exit
```

Finally, repeat the original transaction from the **host**:

```bash
make verify
```

Do not use `curl --insecure`, change the route, or add a firewall rule. Those
actions do not repair an application that already receives and answers the
validated HTTPS request. If manual recovery is unsuccessful, `make reset`
restores the complete known-good state as an escape hatch.
