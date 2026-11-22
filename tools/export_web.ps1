# Builds the CrazyGames web version into build/web and zips it as build/restaurant_tycoon_web.zip
# (upload that zip on the CrazyGames developer portal). Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File tools/export_web.ps1
$ErrorActionPreference = "Stop"
$godot = "$env:USERPROFILE\Desktop\Godot_v4.5\Godot_v4.5.1-stable_win64.exe"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
New-Item -ItemType Directory -Force build/web | Out-Null
& $godot --headless --path . --export-release "CrazyGames (Web)" build/web/index.html | Out-Host
if (-not (Test-Path build/web/index.pck)) { throw "Export failed - see the output above." }
Compress-Archive -Path build/web/* -DestinationPath build/restaurant_tycoon_web.zip -Force
$size = (Get-ChildItem build/web -Recurse | Measure-Object Length -Sum).Sum / 1MB
"Done: build/restaurant_tycoon_web.zip  ({0:N1} MB unzipped)" -f $size
