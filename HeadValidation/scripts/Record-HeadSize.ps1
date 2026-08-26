param(
    [string]$BaseUrl = "http://localhost:5180",
    [string]$OutDir = "artifacts/manual-size-check",
    [string[]]$Routes = @('/plain','/item/42','/slow','/secure','/teapot','/missing-route','/logo.png')
)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

foreach ($r in $Routes) {
    $url = "$BaseUrl$r"
    $safe = $r -replace '/','_' -replace '\\?',''
    $out = Join-Path $OutDir "$($safe.TrimStart('_')).head.timed.txt"

    Write-Host "Measuring HEAD $url -> $out"
    # Use curl.exe available on Windows and many dev boxes
    $cmd = "curl.exe -s -o NUL -w `"status=%{http_code}`nsize=%{size_download}`ntime=%{time_total}`n`" -I `"$url`""
    $res = cmd /c $cmd 2>&1
    Set-Content -Path $out -Value $res
}

Write-Host "Wrote head size/timing files to $OutDir"