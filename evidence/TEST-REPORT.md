# HTTP HEAD validation report

- **Issue:** [dotnet/aspnetcore#68515](https://github.com/dotnet/aspnetcore/issues/68515)
- **Test date:** 2026-08-26; harness assertion update verified 2026-08-27
- **Base commit:** `9489693d9d95f6eb51a105137f327895d0fad48a` (`main`)
- **Build:** .NET SDK `11.0.100-preview.7.26381.103`; ASP.NET Core runtime `11.0.0-preview.7.26381.103`
- **Protocol scope:** cleartext HTTP/1.1 on Windows x64; HTTPS and HTTP/2 were not tested

## Verdict

The verified local and container Static SSR and Interactive Server runs pass the
established Razor component requirements: expected status, HEAD/GET status
parity, and an empty HEAD body. The synchronous `/teapot` status and `X-Test`
header also pass. The `/slow` curl HEAD timing criterion fails because complete
headers become available in milliseconds rather than after the two-second
component delay. A raw HTTP/1.1 client remains connected for approximately two
seconds, so this evidence does not show that server-side component execution
ends early.

The former container columns and unqualified .NET 10 upgrade PASS are not
carried forward. Fresh container runs now include explicit running-container
environment inspection and rendered mode proof. The .NET 10 to .NET 11 behavior
is **not reproducible from committed source**: the supplied external-project
evidence covers only `/counter`, not the requested `/plain` and `/secure`
routes.

> **.NET 10 discrepancy:** The issue expected `HEAD` to return **405 Method Not
> Allowed**, but the actual .NET 10 test returned **404 Not Found**. Therefore,
> the observed result does not reproduce the expected .NET 10 behavior, and no
> .NET 10-to-11 upgrade verdict is claimed.

The `/slow` curl timing difference remains an automated failure. Hot Reload is
verified for file additions and valid Razor route updates in both local render
modes.

The updated harness was also run against the live Static SSR container. It
asserted that HEAD `/plain` executed the component by observing `/hits` increase
by exactly one, recorded `/slow` GET at about 2.01s, curl HEAD completion at
about 0.01s, raw header arrival in milliseconds, and raw connection close at
about two seconds. The timing assertion failed and the aggregate result was
`exitCode=1`: [hits](static-ssr-live-20260827/hits.txt), [timing assertion](static-ssr-live-20260827/slow-timing-assertion.txt),
[raw timing](static-ssr-live-20260827/slow.head.raw.timed.txt), and
[result](static-ssr-live-20260827/result.txt).

## Verified configurations

| Configuration | Evidence path | Render proof | Status/body harness | `/slow` timing |
| --- | --- | --- | --- | --- |
| Local Static SSR | [evidence/local-static-verified-20260826/](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/) | PASS: [render-mode.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/render-mode.txt), [plain.html](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/plain.html) | PASS: [result.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/result.txt), [status/body evidence](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.064399s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow.get.timed.txt), [HEAD 0.002366s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow.head.timed.txt) |
| Local Interactive Server | [evidence/local-interactive-verified-20260826/](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/) | PASS: [render-mode.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/render-mode.txt), [plain.html](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/plain.html) | PASS: [result.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/result.txt), [status/body evidence](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.011545s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow.get.timed.txt), [HEAD 0.002266s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow.head.timed.txt) |
| Container Static SSR | [evidence/container-static-verified-20260826/](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/) | PASS: [container.inspect.json](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/container.inspect.json), [render-mode.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/render-mode.txt), [plain.html](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/plain.html) | PASS: [result.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/result.txt), [status/body evidence](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.023359s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow.get.timed.txt), [HEAD 0.008508s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow.head.timed.txt) |
| Container Interactive Server | [evidence/container-interactive-verified-20260826/](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/) | PASS: [container.inspect.json](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/container.inspect.json), [render-mode.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/render-mode.txt), [plain.html](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/plain.html) | PASS: [result.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/result.txt), [status/body evidence](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.023347s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow.get.timed.txt), [HEAD 0.011873s](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow.head.timed.txt) |

The committed harness is [Test-HeadEndpoints.ps1](https://github.com/surya3655/blazor-head-request-validation/tree/main/HeadValidation/scripts/Test-HeadEndpoints.ps1).
It records the invocation, SDK, branch, base SHA, working-tree state, source
hashes, rendered mode, raw HEAD response bytes, per-method timings, selected
header differences, and an aggregate exit code.

## Hot Reload results

| Configuration | Initial build | File-add route | Existing route update | Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Local Static SSR | PASS: `dotnet watch` built successfully and listened on port 5180 | PASS: `/hot-reload-new` changed from HEAD 404 to 200 without restarting | PASS: `/plain-reloaded` returned HEAD 200 and the former `/plain` route returned 404 | **PASS for valid edits** | [request evidence](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/hotreload.txt), [watch log](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/hotreload-build.log) |
| Local Interactive Server | PASS: `dotnet watch` built successfully and listened on port 5181 | PASS: `/hot-reload-new` changed from HEAD 404 to 200 without restarting | PASS: `/plain-reloaded` returned HEAD 200 and the former `/plain` route returned 404 | **PASS** | [request evidence](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/hotreload.txt), [watch log](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/hotreload-build.log) |

The Static SSR watch log later records `RZ1017` and `RZ2005` for a malformed
`Plain.razor` edit. This does not invalidate the preceding successful file-add
and valid route-update checks; it records the expected compiler response to an
invalid Razor edit. The Interactive Server watch log contains successful apply
messages for both edits without Razor compiler errors.

## Route results

The detailed status files linked above are authoritative. The asserted Razor
component and static-asset routes produced these results in both verified local
configurations:

| Route | GET | HEAD | Result |
| --- | ---: | ---: | --- |
| `/` | 200 | 200 | PASS |
| `/plain` | 200 | 200 | PASS |
| `/item/42` | 200 | 200 | PASS |
| `/slow` status/header parity | 200 | 200 | PASS |
| `/slow` curl completion timing | ~2 seconds | milliseconds | **FAIL: complete HEAD headers are available before the required minimum** |
| `/slow-teapot` | 200 | 200 | PASS for status parity; delayed metadata is an observation |
| `/secure` | 302 | 302 | PASS |
| `/teapot` | 418 | 418 | PASS; `X-Test: hello` preserved |
| `/missing-route` | 404 | 404 | PASS |
| `/logo.png` | 200 | 200 | PASS for status; header difference noted below |

### Route evidence

| Route | Local Static SSR | Local Interactive Server | Container Static SSR | Container Interactive Server |
| --- | --- | --- | --- | --- |
| `/` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/home.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/home.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/home.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/home.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/home.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/home.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/home.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/home.head.headers.txt) |
| `/plain` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/plain.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/plain.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/plain.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/plain.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/plain.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/plain.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/plain.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/plain.head.headers.txt) |
| `/item/42` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/item-42.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/item-42.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/item-42.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/item-42.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/item-42.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/item-42.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/item-42.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/item-42.head.headers.txt) |
| `/slow` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow.head.headers.txt) / [GET timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow.get.timed.txt) / [HEAD timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow.head.timed.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow.head.headers.txt) / [GET timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow.get.timed.txt) / [HEAD timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow.head.timed.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow.head.headers.txt) / [GET timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow.get.timed.txt) / [HEAD timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow.head.timed.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow.head.headers.txt) / [GET timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow.get.timed.txt) / [HEAD timing](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow.head.timed.txt) |
| `/slow-teapot` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/slow-teapot.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/slow-teapot.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/slow-teapot.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/slow-teapot.head.headers.txt) |
| `/secure` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/secure.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/secure.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/secure.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/secure.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/secure.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/secure.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/secure.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/secure.head.headers.txt) |
| `/teapot` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/teapot.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/teapot.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/teapot.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/teapot.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/teapot.head.headers.txt) |
| `/missing-route` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/missing-route.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/missing-route.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/missing-route.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/missing-route.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/missing-route.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/missing-route.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/missing-route.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/missing-route.head.headers.txt) |
| `/logo.png` | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/logo.png.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/logo.png.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/logo.png.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-interactive-verified-20260826/logo.png.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/logo.png.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-static-verified-20260826/logo.png.head.headers.txt) | [GET](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/logo.png.get.headers.txt) / [HEAD](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/container-interactive-verified-20260826/logo.png.head.headers.txt) |

Every route in [head-body-sizes.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/head-body-sizes.txt)
and its interactive counterpart has `HEAD-bytes=0`. This is measured from raw
HTTP/1.1 responses, not inferred from `curl -I`.

## Streaming observations

[Slow.razor](https://github.com/surya3655/blazor-head-request-validation/tree/main/HeadValidation/Components/Pages/Slow.razor) performs one
two-second delay. In the updated Static SSR run, GET took about two seconds and
complete HEAD headers arrived in milliseconds. The raw HEAD connection did not
close until about two seconds had elapsed. HTTP status remained 200 for both,
so status parity passes. The automated curl timing criterion nevertheless
**FAILS** because header completion is below the configured 1.5-second minimum.
This proves early header availability, but does not prove that component
execution ends early. Earlier runs show the same curl timing difference in all
four configurations; raw connection-close timing has only been captured in the
updated Static SSR run.

The harness also brackets a raw HEAD `/plain` request with two GET `/hits`
requests and requires the counter to increase by exactly one. This independently
checks that the HEAD request executes the component; failure contributes to the
aggregate nonzero exit code.

[SlowTeapot.razor](https://github.com/surya3655/blazor-head-request-validation/tree/main/HeadValidation/Components/Pages/SlowTeapot.razor) attempts
to apply status 418 and `X-Test: delayed` after streaming has begun. The delayed
metadata is absent from both GET and HEAD in
[late-metadata.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/late-metadata.txt). This shows
a general late-streaming metadata limitation, not a HEAD-only metadata mismatch.

## Header observations

Status parity does not imply complete header equality. The selected comparison
is recorded in [header-differences.txt](https://github.com/surya3655/blazor-head-request-validation/tree/main/evidence/local-static-verified-20260826/header-differences.txt):

- `/logo.png`: GET has `Content-Length: 1148`; HEAD omits `Content-Length`.
- `/secure`: GET has `Content-Length: 0`; HEAD omits it.
- Transfer framing differences are not treated as representation metadata parity.

RFC 9110 section 9.3.2 says HEAD SHOULD send the same header fields as GET, with
allowances for fields determined only while generating content. The static asset
`Content-Length` omission is therefore recorded explicitly rather than hidden
behind a claim of identical headers.