param(
    # Path to the Godot 4.7.2 executable. Defaults to $env:GODOT, then `godot` on PATH.
    [string]$GodotPath = $env:GODOT
)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $found = Get-Command godot -ErrorAction SilentlyContinue
    if ($found) { $GodotPath = $found.Source }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot executable not found. Pass -GodotPath, set the GODOT environment variable, or put godot on PATH.'
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
