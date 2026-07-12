# Captures a burst of screenshots of a specific window (default: Cyberpunk2077) via
# PrintWindow(PW_RENDERFULLCONTENT) — works while the window is BEHIND other windows,
# so the user can keep the terminal in the foreground.
# Usage: capture-burst.ps1 [-Process Cyberpunk2077] [-Count 6] [-IntervalMs 500] [-OutDir <dir>]
# Output: <OutDir>\burst-<timestamp>-<n>.png ; prints one path per line.
param(
    [string]$Process = "Cyberpunk2077",
    [int]$Count = 6,
    [int]$IntervalMs = 500,
    [string]$OutDir = "$env:TEMP\ingame-verify"
)

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Cap {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint nFlags);
}
"@

$proc = Get-Process $Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) {
    Write-Error "process '$Process' not running or has no window"
    exit 1
}

$rect = New-Object Win32Cap+RECT
[Win32Cap]::GetClientRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
if ($w -le 0 -or $h -le 0) {
    Write-Error "window has no client area (minimized?)"
    exit 1
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$stamp = Get-Date -Format "HHmmss"

for ($i = 1; $i -le $Count; $i++) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    # 2 = PW_RENDERFULLCONTENT: required for DirectX-rendered windows (games)
    [Win32Cap]::PrintWindow($proc.MainWindowHandle, $hdc, 2) | Out-Null
    $g.ReleaseHdc($hdc)
    $path = Join-Path $OutDir "burst-$stamp-$i.png"
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output $path
    if ($i -lt $Count) { Start-Sleep -Milliseconds $IntervalMs }
}
