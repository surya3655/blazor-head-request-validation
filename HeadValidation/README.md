# HTTP HEAD validation for Razor component endpoints

This .NET 11 Preview 7 Blazor Web App reproduces the validation scenario in
[dotnet/aspnetcore#68515](https://github.com/dotnet/aspnetcore/issues/68515).
It uses ordinary Razor component routing: there is no custom HEAD endpoint or
middleware that could hide the behavior under test.

## Scenario coverage

| Route | Real-world case | Expected signed-out status |
| --- | --- | ---: |
| `/plain` | Basic service overview | 200 |
| `/item/42` | Parameterized inventory record | 200 |
| `/slow` | Two-second streaming sales report | 200 |
| `/slow-teapot` | Streaming page that attempts to set status and a header after two seconds | 200 |
| `/secure` | Cookie-protected operations dashboard | 302 |
| `/teapot` | Application-defined status and `X-Test: hello` header | 418 |
| `/missing-route` | Undeclared route | 404 |
| `/logo.png` | Static asset control | 200 |

Every declared test page increments the singleton `HitCounter` from
`OnInitialized`. Read the value from `/hits`.

## Run both required configurations

The profiles change only the root component render mode. Both configurations
use the same component endpoints and application pipeline.

```powershell
dotnet run --launch-profile StaticSsr
./scripts/Test-HeadEndpoints.ps1 -BaseUrl http://localhost:5180
```

```powershell
dotnet run --launch-profile InteractiveServer
./scripts/Test-HeadEndpoints.ps1 -BaseUrl http://localhost:5181 -EvidenceDirectory ./artifacts/head-validation-interactive
```

To verify the render mode visually, open `/plain` and click **Increment**:

| Profile | URL | Expected result after one click |
| --- | --- | --- |
| Static SSR | `http://localhost:5180/plain` | The displayed count remains `0` because no interactive circuit handles the event. |
| Interactive Server | `http://localhost:5181/plain` | The displayed count changes from `0` to `1`. |

The page also displays the `RenderMode` value supplied by the selected launch
profile. The control uses a normal Blazor `@onclick` handler and no custom
JavaScript, so a changed count directly proves that the component is interactive.

The committed script sends HEAD and GET to every component route, compares
statuses, captures raw HTTP/1.1 HEAD responses to prove their bodies are empty,
checks the synchronous custom header, captures `/plain` as render-mode proof,
and times `/slow` once per method. It records selected header differences rather
than claiming byte-for-byte header equality. `/hits` and `/login` are included
as minimal-API controls; their HEAD results are observations, not component-route
assertions.

`/slow-teapot` records whether metadata applied after streaming begins survives.
Because both GET and HEAD currently return 200 without the delayed `X-Test`
header, the result is a general streaming metadata limitation rather than a
HEAD-only status/header mismatch.

For a direct manual comparison, use `curl -I`, not `curl -X HEAD`:

```powershell
curl.exe -I http://localhost:5180/plain
curl.exe -s -o NUL -D - http://localhost:5180/plain
```

## Additional validation matrix

- Published output: run `dotnet publish -c Release -o ./artifacts/publish`, start
  `./artifacts/publish/HeadValidation.exe --urls http://localhost:5182`, and run
  the script with that base URL.
- .NET 10 upgrade: use a committed fixture or commit pair, capture the project
  diff, `dotnet --info`, build logs, and request artifacts for both versions.
  Results from an external project copy are not reproducible evidence.
- Trimming: run `dotnet publish -c Release -p:PublishTrimmed=true` and repeat the
  published-output check. Native AOT isn't supported for interactive Blazor
  Server applications.
- Multiple instances or proxy: run two published instances on separate ports
  behind the proxy and compare headers. `/hits` is intentionally per process.
- Hot Reload: run `dotnet watch --launch-profile StaticSsr`, add or change an
  `@page` route, and send HEAD without restarting.
- IDE and command line: run each launch profile once from VS Code and once with
  `dotnet run`.
- Container: build once, then pass the render mode explicitly and retain
  `docker inspect` output for the running container:

```powershell
docker build -t head-validation .
docker run --name head-static -d -p 5183:8080 -e RenderMode=StaticSsr head-validation
docker inspect head-static > ../evidence/container-static/container.inspect.json
./scripts/Test-HeadEndpoints.ps1 -BaseUrl http://localhost:5183 -ExpectedRenderMode StaticSsr -EvidenceDirectory ../evidence/container-static

docker run --name head-interactive -d -p 5184:8080 -e RenderMode=InteractiveServer head-validation
docker inspect head-interactive > ../evidence/container-interactive/container.inspect.json
./scripts/Test-HeadEndpoints.ps1 -BaseUrl http://localhost:5184 -ExpectedRenderMode InteractiveServer -EvidenceDirectory ../evidence/container-interactive
```

For every matrix entry, retain the generated HEAD and GET headers, raw HEAD
response and body-size files, timings, header-difference summary, rendered mode
proof, server logs, SDK information, run metadata, Git status, and source hashes.

The raw body validator currently targets cleartext HTTP/1.1. HTTPS and HTTP/2
require separate protocol-specific runs and must not be inferred from these
artifacts.