# ---------------------------------------------------------------------------
# Generate telemetry data for the SREA demo.
# Run this 5-10 minutes BEFORE the live demo so App Insights has data.
#
# Usage: .\scripts\generate-errors.ps1 [-ResourceGroup rg-srea-demo]
# ---------------------------------------------------------------------------
param(
    [string]$ResourceGroup = "rg-srea-demo"
)

$ErrorActionPreference = "Stop"

$APP_URL = az deployment group show -g $ResourceGroup -n main `
    --query properties.outputs.appUrl.value -o tsv 2>$null

if (-not $APP_URL) {
    Write-Error "Could not retrieve APP_URL. Is the deployment in resource group '$ResourceGroup' named 'main'?"
    exit 1
}

Write-Host "Target: $APP_URL" -ForegroundColor Cyan
Write-Host "Generating errors - this will take ~2 minutes...`n" -ForegroundColor Cyan

$Rounds = 10

for ($i = 1; $i -le $Rounds; $i++) {
    Write-Host "-- Round $i/$Rounds --" -ForegroundColor White

    # Bug 1: 500 - null dereference on missing order
    try {
        Invoke-WebRequest "$APP_URL/orders/999" -UseBasicParsing -ErrorAction Stop | Out-Null
        Write-Host "  /orders/999        -> 200 (UNEXPECTED)" -ForegroundColor Red
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Write-Host "  /orders/999        -> $code (expect 500)" -ForegroundColor Yellow
    }

    # Bug 2: SQL injection probes — multiple patterns so the agent sees a realistic attack
    $sqliPayloads = @(
        "shipped'%20OR%201=1--",
        "shipped'%20UNION%20SELECT%20NULL--",
        "shipped';%20DROP%20TABLE%20orders--",
        "shipped'%20AND%201=1--"
    )
    foreach ($payload in $sqliPayloads) {
        try {
            Invoke-WebRequest "$APP_URL/orders?status=$payload" -UseBasicParsing -ErrorAction Stop | Out-Null
            Write-Host "  /orders?status=sqli -> 200 (expect 200)" -ForegroundColor Green
        } catch {
            $code = $_.Exception.Response.StatusCode.value__
            Write-Host "  /orders?status=sqli -> $code (UNEXPECTED)" -ForegroundColor Red
        }
    }

    # Bug 3: Secret leak - health endpoint logs connection string
    try {
        Invoke-WebRequest "$APP_URL/health" -UseBasicParsing -ErrorAction Stop | Out-Null
        Write-Host "  /health             -> 200 (expect 200)" -ForegroundColor Green
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        Write-Host "  /health             -> $code (UNEXPECTED)" -ForegroundColor Red
    }

    # Bug 4: Slow endpoint — CONCURRENT requests to spike p95 latency
    # Sequential calls won't trigger the alert — need parallel load
    $slowJobs = 1..5 | ForEach-Object {
        Start-Job -ScriptBlock {
            param($url)
            try { Invoke-WebRequest "$url/slow" -UseBasicParsing -ErrorAction Stop | Out-Null } catch {}
        } -ArgumentList $APP_URL
    }
    $slowJobs | Wait-Job -Timeout 30 | Out-Null
    $slowJobs | Remove-Job -Force
    Write-Host "  /slow x5 concurrent -> done (expect ~5s each)" -ForegroundColor Green

    # Normal traffic so failures stand out
    try { Invoke-WebRequest "$APP_URL/" -UseBasicParsing -ErrorAction Stop | Out-Null } catch {}
    try { Invoke-WebRequest "$APP_URL/orders" -UseBasicParsing -ErrorAction Stop | Out-Null } catch {}
    try { Invoke-WebRequest "$APP_URL/orders/1" -UseBasicParsing -ErrorAction Stop | Out-Null } catch {}

    Start-Sleep -Seconds 2
}

Write-Host "`nDone. Wait 3-5 minutes for App Insights ingestion, then start the demo." -ForegroundColor Cyan
