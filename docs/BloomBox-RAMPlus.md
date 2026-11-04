# RAM+ experimental integration

RAM+ now has two independent states: a user request to enable the Apple capability,
and validation of the currently installed signature. A server approval never marks
the running process as entitled. Reinstallation is still required.

## Flow

1. In Modules → RAM+, request the permission. BloomBox records an expiring request
   for its exact installed bundle identifier and signing team. LiveProcess is
   included only when its separate identifier and matching team can be verified.
2. Open the bundled SideStore's My Apps screen. Its normal App ID lookup provides
   a current authenticated Developer Services request. Only that exact HTTPS
   endpoint is observed; the original response is passed through unchanged.
3. Within the SideStore process, RAM+ uses the current request headers in memory
   to read the selected App ID and all its existing capabilities, patch only
   Increased Memory Limit, then read it back. Credentials/headers are never
   written to preferences, files, or logs by this integration. Redirects are refused.
4. Apple approval is reported separately. Reinstall BloomBox using SideStore,
   keeping extensions and app data, and re-open RAM+ to validate the installed
   entitlement and provisioning profile. A normal refresh may retain an old profile.

Missing or mismatched teams, unknown App IDs, incomplete capability lists, failed
HTTP responses, missing readback confirmation, cancellation, and expiry all fail
closed. A file lock prevents parallel mutation attempts across SideStore processes.
A submitted request whose response is lost is reported as uncertain, never retried
automatically. Cancellation cannot undo a request already received by Apple.

The request expires after five minutes. If SideStore requires authentication, sign
in there and request RAM+ again after signing in if the first request has expired.
The manual GetMoreRam route remains available as a fallback.

## References

This implementation uses the same Developer Services capability operation as
[GetMoreRam](https://github.com/hugeBlack/GetMoreRam) and
[StosSign](https://github.com/stossy11/StosSign). The existing bundled SideStore
performs authentication; no separate authentication implementation is included.
The exact App ID lookup format is grounded in
[SideSign](https://github.com/SideStore/SideSign).

## Validation

CI covers entitlement/profile validation and the portal request planner: exact
HTTPS endpoint, team/App ID matching, preserving existing capability settings and
relationships, missing capability details, server errors, and approved/disabled
readback. An iPhone test is required to verify Apple's live response format and
SideStore's URL loading path. Compilation alone does not establish live activation.

## Resigning caveat (SideStore free accounts)

An App ID enabled on Apple's server is **not** the installed process permission.
As of October 2026, SideStore/SideSign has an unresolved upstream report
[SideStore#1616](https://github.com/SideStore/SideStore/issues/1616) where a
free-team reinstall drops the Increased Memory Limit entitlement. A proposed
[SideSign#4](https://github.com/SideStore/SideSign/pull/4) adds a v1 capability
request but is not a confirmed fix for the bundled SideStore nightly.

The BloomBox unsigned IPA explicitly requests
`com.apple.developer.kernel.increased-memory-limit=true` in both the main
executable and LiveProcess source entitlements. CI checks the **actual IPA**
executables and fails if the requests disappear during packaging. This does not
guarantee that the signer preserves them: after reinstalling, the RAM+ screen
checks the installed process entitlement and provisioning profile separately.
If either fails, the UI must not claim success. Keep the IPA and its extensions
when reinstalling; do not delete app data just to retry.

A v1 PATCH may return HTTP 204 with an empty body. This is accepted **only**
as an acknowledgement: BloomBox then fetches the App ID again and requires an
enabled Increased Memory Limit capability before reporting server approval.
Unknown or failed readbacks are never promoted to success.

## Device-test checklist

1. Before requesting, record the main app's RAM+, profile, and LiveProcess states
   from Modules -> RAM+. Never paste account tokens or provisioning profiles.
2. Trigger the permission request, then open the bundled SideStore's My Apps page
   within five minutes using the team which signed BloomBox.
3. Distinguish account mismatch, expired request, explicit Apple denial, uncertain
   submission, and approved server-side App ID.
4. After approval, **reinstall** from the IPA (not merely Refresh All), preserving
   extensions and data. Open RAM+ again; the process and profile must both pass.
5. Test an invited emulator inside the primary process and, separately, in
   LiveProcess mode if used. Do not infer a guest's JIT state from RAM+.
6. If SideStore drops the signed entitlement, investigate the upstream SideSign
   signer or preserve the manual Xcode/GetMoreRam route; do not override the
   validation screen or label the feature active.

## Incomplete capability list diagnostic (2026-10-29)

An iOS 27 report reached the authenticated SideStore read stage but Apple's
relationship `meta.paging.total` disagreed with the count in
`relationships.bundleIdCapabilities.data`. This is not a Wi-Fi/LTE problem and
is not proof that Apple accepted RAM+. In the first implementation the nested
query requested at most 50 capabilities; this patch requests up to 200. A
mismatch still blocks **all writes** and now reports the counts and whether
another page exists. The message contains no Apple ID, tokens or bundle IDs.
If the new limit does not resolve the mismatch, use the counts to implement a
verified pagination read rather than dropping the safety guard or clearing
other Apple capabilities. The provisioning profile is unchanged until a new
signing/install step actually includes RAM+.


## Regression: Apple reports zero total for one capability on iOS 27

The on-device response contained **one capability record**, while its pagination metadata `total` was **zero**. Increasing the requested limit to 200 did not resolve this inconsistency. BloomBox rejected the response before submitting changes.

This update treats zero with nonempty records as **unreliable metadata**, NOT as proof that the list is complete. The request proceeds only when:

- No nonempty `next` pagination link exists.
- The page contains fewer than 200 records.
- Every capability has unique IDs, a strict enabled boolean and complete relationships.
- A second authenticated read returns an equivalent set of IDs, attributes and relationships.

Positive reported totals still must match the records. A full page, missing records or inconsistent repeat reads block all changes. Following a PATCH, BloomBox checks both RAM+ and preservation of unrelated capabilities. Actual installation signing still needs on-device verification.


## RP4: compare the capability edit state

The RP3 device diagnostic identified a difference in an attribute other than
`enabled` or `settings`, with the same capability record ID. The exact changing
attribute/value was not captured. No Apple write occurred in that attempt.

Capability attribute comparison and PATCH serialization now use only `enabled`
and `settings`, matching the capability edit input constructed by
[StosSign updateAppID](https://github.com/stossy11/StosSign/blob/main/Sources/StosSign_API/AppleAPI.swift),
which GetMoreRam calls. Response-only attributes are not sent back to Apple.
All existing capability records and relationships remain preserved; changes in
settings, enabled state, linkage, record IDs or capability counts still block
an unstable read. Zero-total responses still require two matching reads.

Regression fixtures simulate differing extra attributes; they are not captured
Apple payloads. Tests also cover genuine enabled/settings changes and ensure
existing settings and relationships survive PATCH construction. On-device
activation and subsequent SideStore signing still require verification.


## Reinstallación experimental sin cambiar de versión (RP5)

La activación real de RAM+ fue confirmada en iPhone 14 Pro con iOS 27:
la respuesta de Apple y las validaciones del proceso/perfil fueron positivas;
MelonNX informó "Increased Memory Limit: Enabled". **Este resultado
corresponde a RP4 y no comprueba todavía el nuevo instalador de RP5.**

- El botón **Activar y reinstalar** conserva la solicitud y comprobación de
  Apple tal como funcionaban en RP4. Una segunda solicitud no se envía
  mientras exista otra en curso. Si el permiso ya funciona en la instalación
  actual, no se inicia ninguna reinstalación.
- Tras la confirmación de Apple, el UI recupera la operación guardada y busca
  una IPA oficial publicada por este proyecto. El descubrimiento automático
  exige: commit de origen de 40 caracteres grabado en el paquete, etiqueta de
  versión exacta, archivo \`BloomBox-SideStore-unsigned.ipa\` único, SHA-256
  publicado en el asset de GitHub y URL HTTPS de una release de este repositorio.
  El archivo se descarga para comprobar el SHA-256, su estructura ZIP, versión,
  build, bundle base, extensiones, App Groups y commit del paquete.
- Si se cumple todo, se envía a SideStore mediante el esquema **oficial** de
  instalación remota \`sidestore://install?url=...\`. El enrutamiento de
  BloomBox ya entrega ese esquema al SideStore integrado. El instalador puede
  necesitar VPN, autenticación o confirmación. SideStore descarga el asset de
  nuevo porque su esquema remoto no permite entregarle el archivo local
  inspeccionado; no se afirma que la instalación sea silenciosa.
- Si la IPA correspondiente es un artefacto temporal de Actions, no existe
  una release verificable, requiere autenticación, caducó o falta un commit
  exacto en la app instalada, **no se sustituye por otra versión**. Se ofrece
  importar la IPA original del usuario. El ZIP se comprueba localmente, pero
  su origen no puede autenticarse por esa vía. El paso pendiente es compartir
  el archivo a SideStore (o guardarlo en Archivos y seleccionarlo con +).
  **No desinstalar ni borrar datos**; conservar extensiones durante la firma.
- El estado se guarda en el contenedor de documentos y UserDefaults del grupo,
  **sin credenciales ni tokens**. Una entrega en curso pasa a \`verifying\` al
  regresar, sin intentos automáticos repetidos. El botón de reintento es
  explícito. El resultado solo se muestra como confirmado al comprobar
  entitlement del proceso y perfil instalado vigente.
- La reautenticación de SideStore, los diálogos de iOS y la sustitución de la
  propia app mientras el SideStore integrado está ejecutándose **no se pueden
  verificar en CI** y deben probarse con el iPhone. No se tocó JIT, main ni
  se creó una release. La opción "actualizar a la última versión" queda aparte.

Referencias: [esquema oficial de SideStore](https://docs.sidestore.io/docs/advanced/url-schema)
y [enrutamiento de SideStore integrado](https://github.com/LiveContainer/LiveContainer/issues/1086).


## Hotfix: latest public release for RAM+ reinstall (2026-10-30)

The preceding RP5 section describes the old exact-build installer.
That implementation could not discover public BloomBox v1.3.0: the
embedded **LiveContainer** Info.plist still reports
\`CFBundleShortVersionString=3.8.10\`, which is deliberately separate
from the BloomBox GitHub release tag \`v1.3.0\`. Searching for
\`tag_name == "v" + installed CFBundleShortVersionString\` therefore
returned no asset, even for a valid official release.

The new logic uses the fixed GitHub API endpoint
\`repos/adri23rep-stack/BloomBox/releases/latest\` for the latest
**stable, public, nondraft** release. It requires exactly one official
\`BloomBox-SideStore-unsigned.ipa\`, HTTPS release URL under the
canonical repository and exact tag, GitHub SHA-256, and bounded download
size. The downloaded ZIP is inspected and hashed *before* requesting
the SideStore handoff. The signed installation identity must match the
source base app ID (or its SideStore suffix), and installed extension
bundles may not disappear in the update. The package must contain
LiveProcess, LiveWidgetExtension and SideStore. The new release can
have a different version/build/commit; Apple App Group names are not
compared verbatim with the unsigned archive because SideStore remaps
them during signing.

When the installed build differs from GitHub's current release commit,
the user must explicitly confirm updating to the stable release before
SideStore opens. The selected tag and digest are pinned between review
and confirmation: if GitHub published a different asset in the meantime,
confirmation is required again. This protects owners using a
*JIT experimental* build from accidentally overwriting their working
experiment with the latest **stable** release. Entering the RAM+ screen
never triggers installation without an explicit action.

If GitHub is unavailable, SHA/identity check fails or the handoff
fails, do not delete the existing installation. The user can choose an
IPA manually (source unverified), or share the validated local IPA if
the SideStore URL handoff fails. Actual Apple RAM+ entitlement is
confirmed only by reading the installed signature and provisioning
profile **after** SideStore finishes; server-side approval is not proof
of installed capability.

Known limitation: SideStore may still drop the RAM+ entitlement when
re-signing on certain account setups. This upstream issue is separate
from latest-release discovery; it cannot be bypassed by downloading
another IPA. Device validation and a new public release are required
before existing users can benefit from this hotfix.
