param([int]$Port = 8090)

$ErrorActionPreference = 'Stop'
$rootPath = $PSScriptRoot
Add-Type -AssemblyName System.Web

function Get-LocalIPs {
    try {
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
            Select-Object -ExpandProperty IPAddress
    } catch {
        @()
    }
}

$listener = $null
$networkBound = $false
try {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$Port/")
    $listener.Start()
    $networkBound = $true
} catch {
    try { $listener.Stop() } catch {}
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
}

Write-Host ""
Write-Host "==============================================="
Write-Host " Koutei-hyou - Local Server" -ForegroundColor Cyan
Write-Host "==============================================="
Write-Host ""
Write-Host "  This PC:   http://localhost:$Port/" -ForegroundColor Green
if ($networkBound) {
    foreach ($ip in (Get-LocalIPs)) {
        Write-Host "  iPad/LAN:  http://${ip}:$Port/" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "  (Open the LAN URL in iPad Safari on the same Wi-Fi)" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "  NOTE: LAN access needs admin rights." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Stop: Ctrl+C or close this window"
Write-Host "==============================================="
Write-Host ""

$mimes = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
    '.webmanifest' = 'application/manifest+json'
}

while ($listener.IsListening) {
    $ctx = $null
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response

        $path = [System.Web.HttpUtility]::UrlDecode($req.Url.LocalPath)
        if ($path -eq '/') { $path = '/index.html' }
        $relPath = $path.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $file = Join-Path $rootPath $relPath

        $fullRoot = [System.IO.Path]::GetFullPath($rootPath)
        $fullFile = [System.IO.Path]::GetFullPath($file)
        if (-not $fullFile.StartsWith($fullRoot)) {
            $res.StatusCode = 403
        } elseif (Test-Path $file -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            $mime = if ($mimes.ContainsKey($ext)) { $mimes[$ext] } else { 'application/octet-stream' }
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $res.ContentType = $mime
            $res.Headers.Add('Cache-Control', 'no-cache')
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $res.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $res.OutputStream.Write($msg, 0, $msg.Length)
        }
    } catch {
        if ($ctx) {
            try { $ctx.Response.StatusCode = 500 } catch {}
        }
    } finally {
        if ($ctx) {
            try { $ctx.Response.OutputStream.Close() } catch {}
        }
    }
}
