# HTTP HEAD validation report

- **Issue:** [dotnet/aspnetcore#68515](https://github.com/dotnet/aspnetcore/issues/68515)
- **Test date:** 2026-08-26
- **Base commit:** `9489693d9d95f6eb51a105137f327895d0fad48a` (`main`)
- **Build:** .NET SDK `11.0.100-preview.7.26381.103`; ASP.NET Core runtime `11.0.0-preview.7.26381.103`
- **Protocol scope:** cleartext HTTP/1.1 on Windows x64; HTTPS and HTTP/2 were not tested

## Verdict

The verified local and container Static SSR and Interactive Server runs pass the
established Razor component requirements: expected status, HEAD/GET status
parity, and an empty HEAD body. The synchronous `/teapot` status and `X-Test`
header also pass. The `/slow` streaming-completion timing check fails in all four
configurations because HEAD returns before the two-second component operation
that GET completes.

The former container columns and unqualified .NET 10 upgrade PASS are not
carried forward. Fresh container runs now include explicit running-container
environment inspection and rendered mode proof. The .NET 10 to .NET 11 behavior
is validated for the tested `/counter` route using the supplied external-project
evidence. The `/slow` timing difference is retained as a failure. Hot Reload is
verified for file additions and valid Razor route updates in both local render
modes.

## Verified configurations

| Configuration | Evidence path | Render proof | Status/body harness | `/slow` timing |
| --- | --- | --- | --- | --- |
| Local Static SSR | [evidence/local-static-verified-20260826/](local-static-verified-20260826/) | PASS: [render-mode.txt](local-static-verified-20260826/render-mode.txt), [plain.html](local-static-verified-20260826/plain.html) | PASS: [result.txt](local-static-verified-20260826/result.txt), [status/body evidence](local-static-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.064399s](local-static-verified-20260826/slow.get.timed.txt), [HEAD 0.002366s](local-static-verified-20260826/slow.head.timed.txt) |
| Local Interactive Server | [evidence/local-interactive-verified-20260826/](local-interactive-verified-20260826/) | PASS: [render-mode.txt](local-interactive-verified-20260826/render-mode.txt), [plain.html](local-interactive-verified-20260826/plain.html) | PASS: [result.txt](local-interactive-verified-20260826/result.txt), [status/body evidence](local-interactive-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.011545s](local-interactive-verified-20260826/slow.get.timed.txt), [HEAD 0.002266s](local-interactive-verified-20260826/slow.head.timed.txt) |
| Container Static SSR | [evidence/container-static-verified-20260826/](container-static-verified-20260826/) | PASS: [container.inspect.json](container-static-verified-20260826/container.inspect.json), [render-mode.txt](container-static-verified-20260826/render-mode.txt), [plain.html](container-static-verified-20260826/plain.html) | PASS: [result.txt](container-static-verified-20260826/result.txt), [status/body evidence](container-static-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.023359s](container-static-verified-20260826/slow.get.timed.txt), [HEAD 0.008508s](container-static-verified-20260826/slow.head.timed.txt) |
| Container Interactive Server | [evidence/container-interactive-verified-20260826/](container-interactive-verified-20260826/) | PASS: [container.inspect.json](container-interactive-verified-20260826/container.inspect.json), [render-mode.txt](container-interactive-verified-20260826/render-mode.txt), [plain.html](container-interactive-verified-20260826/plain.html) | PASS: [result.txt](container-interactive-verified-20260826/result.txt), [status/body evidence](container-interactive-verified-20260826/status-comparison.txt) | **FAIL:** [GET 2.023347s](container-interactive-verified-20260826/slow.get.timed.txt), [HEAD 0.011873s](container-interactive-verified-20260826/slow.head.timed.txt) |

The committed harness is [Test-HeadEndpoints.ps1](../HeadValidation/scripts/Test-HeadEndpoints.ps1).
It records the invocation, SDK, branch, base SHA, working-tree state, source
hashes, rendered mode, raw HEAD response bytes, per-method timings, selected
header differences, and an aggregate exit code.

## Hot Reload results

| Configuration | Initial build | File-add route | Existing route update | Result | Evidence |
| --- | --- | --- | --- | --- | --- |
| Local Static SSR | PASS: `dotnet watch` built successfully and listened on port 5180 | PASS: `/hot-reload-new` changed from HEAD 404 to 200 without restarting | PASS: `/plain-reloaded` returned HEAD 200 and the former `/plain` route returned 404 | **PASS for valid edits** | [request evidence](local-static-verified-20260826/hotreload.txt), [watch log](local-static-verified-20260826/hotreload-build.log) |
| Local Interactive Server | PASS: `dotnet watch` built successfully and listened on port 5181 | PASS: `/hot-reload-new` changed from HEAD 404 to 200 without restarting | PASS: `/plain-reloaded` returned HEAD 200 and the former `/plain` route returned 404 | **PASS** | [request evidence](local-interactive-verified-20260826/hotreload.txt), [watch log](local-interactive-verified-20260826/hotreload-build.log) |

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
| `/slow` streaming completion timing | ~2 seconds | milliseconds | **FAIL: HEAD returns before the component operation completes** |
| `/slow-teapot` | 200 | 200 | PASS for status parity; delayed metadata is an observation |
| `/secure` | 302 | 302 | PASS |
| `/teapot` | 418 | 418 | PASS; `X-Test: hello` preserved |
| `/missing-route` | 404 | 404 | PASS |
| `/logo.png` | 200 | 200 | PASS for status; header difference noted below |

### Route evidence

| Route | Local Static SSR | Local Interactive Server | Container Static SSR | Container Interactive Server |
| --- | --- | --- | --- | --- |
| `/` | [GET](local-static-verified-20260826/home.get.headers.txt) / [HEAD](local-static-verified-20260826/home.head.headers.txt) | [GET](local-interactive-verified-20260826/home.get.headers.txt) / [HEAD](local-interactive-verified-20260826/home.head.headers.txt) | [GET](container-static-verified-20260826/home.get.headers.txt) / [HEAD](container-static-verified-20260826/home.head.headers.txt) | [GET](container-interactive-verified-20260826/home.get.headers.txt) / [HEAD](container-interactive-verified-20260826/home.head.headers.txt) |
| `/plain` | [GET](local-static-verified-20260826/plain.get.headers.txt) / [HEAD](local-static-verified-20260826/plain.head.headers.txt) | [GET](local-interactive-verified-20260826/plain.get.headers.txt) / [HEAD](local-interactive-verified-20260826/plain.head.headers.txt) | [GET](container-static-verified-20260826/plain.get.headers.txt) / [HEAD](container-static-verified-20260826/plain.head.headers.txt) | [GET](container-interactive-verified-20260826/plain.get.headers.txt) / [HEAD](container-interactive-verified-20260826/plain.head.headers.txt) |
| `/item/42` | [GET](local-static-verified-20260826/item-42.get.headers.txt) / [HEAD](local-static-verified-20260826/item-42.head.headers.txt) | [GET](local-interactive-verified-20260826/item-42.get.headers.txt) / [HEAD](local-interactive-verified-20260826/item-42.head.headers.txt) | [GET](container-static-verified-20260826/item-42.get.headers.txt) / [HEAD](container-static-verified-20260826/item-42.head.headers.txt) | [GET](container-interactive-verified-20260826/item-42.get.headers.txt) / [HEAD](container-interactive-verified-20260826/item-42.head.headers.txt) |
| `/slow` | [GET](local-static-verified-20260826/slow.get.headers.txt) / [HEAD](local-static-verified-20260826/slow.head.headers.txt) / [GET timing](local-static-verified-20260826/slow.get.timed.txt) / [HEAD timing](local-static-verified-20260826/slow.head.timed.txt) | [GET](local-interactive-verified-20260826/slow.get.headers.txt) / [HEAD](local-interactive-verified-20260826/slow.head.headers.txt) / [GET timing](local-interactive-verified-20260826/slow.get.timed.txt) / [HEAD timing](local-interactive-verified-20260826/slow.head.timed.txt) | [GET](container-static-verified-20260826/slow.get.headers.txt) / [HEAD](container-static-verified-20260826/slow.head.headers.txt) / [GET timing](container-static-verified-20260826/slow.get.timed.txt) / [HEAD timing](container-static-verified-20260826/slow.head.timed.txt) | [GET](container-interactive-verified-20260826/slow.get.headers.txt) / [HEAD](container-interactive-verified-20260826/slow.head.headers.txt) / [GET timing](container-interactive-verified-20260826/slow.get.timed.txt) / [HEAD timing](container-interactive-verified-20260826/slow.head.timed.txt) |
| `/slow-teapot` | [GET](local-static-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](local-static-verified-20260826/slow-teapot.head.headers.txt) | [GET](local-interactive-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](local-interactive-verified-20260826/slow-teapot.head.headers.txt) | [GET](container-static-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](container-static-verified-20260826/slow-teapot.head.headers.txt) | [GET](container-interactive-verified-20260826/slow-teapot.get.headers.txt) / [HEAD](container-interactive-verified-20260826/slow-teapot.head.headers.txt) |
| `/secure` | [GET](local-static-verified-20260826/secure.get.headers.txt) / [HEAD](local-static-verified-20260826/secure.head.headers.txt) | [GET](local-interactive-verified-20260826/secure.get.headers.txt) / [HEAD](local-interactive-verified-20260826/secure.head.headers.txt) | [GET](container-static-verified-20260826/secure.get.headers.txt) / [HEAD](container-static-verified-20260826/secure.head.headers.txt) | [GET](container-interactive-verified-20260826/secure.get.headers.txt) / [HEAD](container-interactive-verified-20260826/secure.head.headers.txt) |
| `/teapot` | [GET](local-static-verified-20260826/teapot.get.headers.txt) / [HEAD](local-static-verified-20260826/teapot.head.headers.txt) | [GET](local-interactive-verified-20260826/teapot.get.headers.txt) / [HEAD](local-interactive-verified-20260826/teapot.head.headers.txt) | [GET](container-static-verified-20260826/teapot.get.headers.txt) / [HEAD](container-static-verified-20260826/teapot.head.headers.txt) | [GET](container-interactive-verified-20260826/teapot.get.headers.txt) / [HEAD](container-interactive-verified-20260826/teapot.head.headers.txt) |
| `/missing-route` | [GET](local-static-verified-20260826/missing-route.get.headers.txt) / [HEAD](local-static-verified-20260826/missing-route.head.headers.txt) | [GET](local-interactive-verified-20260826/missing-route.get.headers.txt) / [HEAD](local-interactive-verified-20260826/missing-route.head.headers.txt) | [GET](container-static-verified-20260826/missing-route.get.headers.txt) / [HEAD](container-static-verified-20260826/missing-route.head.headers.txt) | [GET](container-interactive-verified-20260826/missing-route.get.headers.txt) / [HEAD](container-interactive-verified-20260826/missing-route.head.headers.txt) |
| `/logo.png` | [GET](local-static-verified-20260826/logo.png.get.headers.txt) / [HEAD](local-static-verified-20260826/logo.png.head.headers.txt) | [GET](local-interactive-verified-20260826/logo.png.get.headers.txt) / [HEAD](local-interactive-verified-20260826/logo.png.head.headers.txt) | [GET](container-static-verified-20260826/logo.png.get.headers.txt) / [HEAD](container-static-verified-20260826/logo.png.head.headers.txt) | [GET](container-interactive-verified-20260826/logo.png.get.headers.txt) / [HEAD](container-interactive-verified-20260826/logo.png.head.headers.txt) |

Every route in [head-body-sizes.txt](local-static-verified-20260826/head-body-sizes.txt)
and its interactive counterpart has `HEAD-bytes=0`. This is measured from raw
HTTP/1.1 responses, not inferred from `curl -I`.

## Streaming observations

[Slow.razor](../HeadValidation/Components/Pages/Slow.razor) performs one
two-second delay. A single static GET took about two seconds, while HEAD headers
arrived in milliseconds: [GET timing](local-static-verified-20260826/slow.get.timed.txt)
and [HEAD timing](local-static-verified-20260826/slow.head.timed.txt). HTTP status
remained 200 for both, so status parity passes. The streaming-completion timing
check nevertheless **FAILS** because HEAD returns before the component's
two-second asynchronous operation completes. The same timing failure occurs in
Local Static SSR, Local Interactive Server, Container Static SSR, and Container
Interactive Server.

[SlowTeapot.razor](../HeadValidation/Components/Pages/SlowTeapot.razor) attempts
to apply status 418 and `X-Test: delayed` after streaming has begun. The delayed
metadata is absent from both GET and HEAD in
[late-metadata.txt](local-static-verified-20260826/late-metadata.txt). This shows
a general late-streaming metadata limitation, not a HEAD-only metadata mismatch.

## Header observations

Status parity does not imply complete header equality. The selected comparison
is recorded in [header-differences.txt](local-static-verified-20260826/header-differences.txt):

- `/logo.png`: GET has `Content-Length: 1148`; HEAD omits `Content-Length`.
- `/secure`: GET has `Content-Length: 0`; HEAD omits it.
- Transfer framing differences are not treated as representation metadata parity.

RFC 9110 section 9.3.2 says HEAD SHOULD send the same header fields as GET, with
allowances for fields determined only while generating content. The static asset
`Content-Length` omission is therefore recorded explicitly rather than hidden
behind a claim of identical headers.