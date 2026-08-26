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

The script sends HEAD and GET to every route, compares statuses, verifies that
HEAD bodies are empty, checks the HTML content type and custom header, proves
that HEAD renders the page through `/hits`, times `/slow`, and saves full raw
headers under `artifacts/`.

For a direct manual comparison, use `curl -I`, not `curl -X HEAD`:

```powershell
curl.exe -I http://localhost:5180/plain
curl.exe -s -o NUL -D - http://localhost:5180/plain
```

## Additional validation matrix

- Published output: run `dotnet publish -c Release -o ./artifacts/publish`, start
  `./artifacts/publish/HeadValidation.exe --urls http://localhost:5182`, and run
  the script with that base URL.
- .NET 10 upgrade: change only `TargetFramework` and the SDK pin to a .NET 10
  installation, record the expected 405 responses, then restore .NET 11 and
  confirm the assertions pass. Do not add a custom HEAD mapping.
- Trimming: run `dotnet publish -c Release -p:PublishTrimmed=true` and repeat the
  published-output check. Native AOT isn't supported for interactive Blazor
  Server applications.
- Multiple instances or proxy: run two published instances on separate ports
  behind the proxy and compare headers. `/hits` is intentionally per process.
- Hot Reload: run `dotnet watch --launch-profile StaticSsr`, add or change an
  `@page` route, and send HEAD without restarting.
- IDE and command line: run each launch profile once from VS Code and once with
  `dotnet run`.
- Container: run `docker build -t head-validation .`, then
  `docker run --rm -p 5183:8080 head-validation`; validate port 5183.

For every matrix entry, retain the generated HEAD and GET header files, the
`hits.txt` before/after values, the timing file, server logs, SDK version, and
the exact launch command with the validation report.