param(
    [string]$GodotPath = 'C:\Users\lukep\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot executable not found. Pass -GodotPath with the path to Godot 4.7.2.'
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $PSScriptRoot '.local-data\appdata'
    $env:LOCALAPPDATA = Join-Path $PSScriptRoot '.local-data\cache'
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    & $GodotPath --path $PSScriptRoot
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
