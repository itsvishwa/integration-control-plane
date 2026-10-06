# TLS for runtime management calls

The ICP calls each MI runtime's management API directly: to show artifact source and WSDLs,
read local entries and parameters, enable or disable artifacts, toggle tracing and statistics,
and so on. These calls go to the runtime's `managementHostname:managementPort` over HTTPS.

Two settings in `conf/deployment.toml` control how the ICP verifies the runtime's certificate.

| Setting | Section | Default | Effect |
|---|---|---|---|
| `artifactsApiAllowInsecureTLS` | top level **and** `[icp_server.storage]` | `true` | `true` skips certificate validation. |
| `artifactsApiTrustStorePath` / `artifactsApiTrustStorePassword` | `[icp_server.storage]` | empty | Truststore used to validate the certificate while validation is on. Empty uses the JVM's default `cacerts`. |

`artifactsApiAllowInsecureTLS` is read in two places: the top-level key covers the console's
management views and actions (artifact source and WSDL, local entries, loggers, MI users and
so on), and the `[icp_server.storage]` key covers artifact control commands (enable, disable,
statistics) and tracing changes. Set both.

## Trusting an internal CA

When the runtime, or a gateway in front of it, presents a certificate issued by a private or
internal CA:

1. Create a truststore that holds the CA certificate:

   ```bash
   keytool -importcert -alias internal-ca \
     -file /path/to/internal-ca.crt \
     -storetype PKCS12 \
     -keystore ../conf/security/mi-truststore.p12 \
     -storepass truststore-password
   ```

   The truststore replaces the JVM default for these calls, so if some runtimes use publicly
   signed certificates, import their CAs too, or start from a copy of
   `conf/security/client-truststore.jks`.

2. Configure it and turn validation on:

   ```toml
   artifactsApiAllowInsecureTLS = false

   [icp_server.storage]
   artifactsApiAllowInsecureTLS = false
   artifactsApiTrustStorePath = "../conf/security/mi-truststore.p12"
   artifactsApiTrustStorePassword = "truststore-password"
   ```

   The password can be encrypted with the cipher tool: set
   `artifactsApiTrustStorePassword = "$secret{artifactsApiTrustStorePassword}"` and put the
   encrypted value under `[icp_server.storage.secrets]`.

3. Restart the ICP.

The ICP refuses to start if `artifactsApiTrustStorePath` points to a file that does not exist.
It logs a warning at startup if a truststore is set while either `artifactsApiAllowInsecureTLS`
is still `true`, because the truststore is not used while validation is off.

The certificate's host name must also match the runtime's `managementHostname`.

## Without a truststore setting

Before `artifactsApiTrustStorePath` was available, the only way to trust an internal CA with
validation on was to import it into the `cacerts` of the JRE that runs the ICP:

```bash
keytool -importcert -alias internal-ca -file internal-ca.crt -cacerts -storepass changeit
```

This still works when `artifactsApiTrustStorePath` is empty, but it is lost on a JRE upgrade
and widens trust for the whole JVM, so prefer the setting above.
