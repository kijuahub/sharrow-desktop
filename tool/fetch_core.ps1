# Downloads Xray-core, geo files and Wintun into .\core for bundling with the Windows build.
#   pwsh tool/fetch_core.ps1 [-Arch 64|arm64-v8a]
param([string]$Arch = '64')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root 'core'
$tmp = Join-Path $env:TEMP "sharrow-core-$(Get-Random)"
New-Item -ItemType Directory -Force $out, $tmp | Out-Null

try {
  Invoke-WebRequest "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-windows-$Arch.zip" -OutFile "$tmp\xray.zip"
  Expand-Archive "$tmp\xray.zip" "$tmp\xray" -Force
  Copy-Item "$tmp\xray\xray.exe", "$tmp\xray\geoip.dat", "$tmp\xray\geosite.dat" $out -Force

  $wArch = if ($Arch -like 'arm64*') { 'arm64' } else { 'amd64' }
  Copy-Item (Join-Path $root "windows\wintun\wintun-$wArch.dll") (Join-Path $out 'wintun.dll') -Force

  & "$out\xray.exe" version | Select-Object -First 1
} finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
