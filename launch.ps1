$rscript = "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"
$appDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$port    = 3838

Write-Host "Starting R Plot AI Assistant..." -ForegroundColor Cyan

# Start Rscript in background
$proc = Start-Process -FilePath $rscript `
    -ArgumentList "run_app.R" `
    -WorkingDirectory $appDir `
    -PassThru -NoNewWindow

# Poll until server responds (max 30s)
Write-Host "Waiting for server..." -ForegroundColor Yellow
$ready = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Seconds 1
    try {
        $null = Invoke-WebRequest -Uri "http://127.0.0.1:$port" -TimeoutSec 1 -UseBasicParsing
        $ready = $true
        break
    } catch {}
    Write-Host "  $i / 30 ..." -ForegroundColor DarkGray
}

if ($ready) {
    Write-Host "Server ready! Opening browser..." -ForegroundColor Green
    Start-Process "http://localhost:$port"
} else {
    Write-Host "Server did not start in 30s. Please open http://localhost:$port manually." -ForegroundColor Red
}

Write-Host ""
Write-Host "App is running. Close the R window to stop." -ForegroundColor Cyan
Write-Host "Press Enter to exit this window..."
Read-Host
