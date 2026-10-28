# Windows setup for the GPT Codex background launcher.
param([string]$NodePath,[string]$CodexPath)
$ErrorActionPreference = 'Stop'
if (-not $NodePath) { $NodePath = (Get-Command node -ErrorAction Stop).Source }
if (-not $CodexPath) { $CodexPath = (Get-Command codex -ErrorAction Stop).Source }
foreach ($ffExecutable in @($NodePath,$CodexPath)) {
 if (-not (Test-Path -LiteralPath $ffExecutable -PathType Leaf)) { throw "Executable not found: $ffExecutable" }
 if ([IO.Path]::GetExtension($ffExecutable) -ne '.exe') { throw 'Use native node.exe and codex.exe paths. Pass -NodePath or -CodexPath if PATH resolves to a command wrapper.' }
}
$launcherDirectory = Join-Path $env:LOCALAPPDATA 'FurniForge'
New-Item -ItemType Directory -Path $launcherDirectory -Force | Out-Null
$launcherConfig = @{ node=(Resolve-Path -LiteralPath $NodePath).Path; codex=(Resolve-Path -LiteralPath $CodexPath).Path; server=(Join-Path $PSScriptRoot 'server/index.mjs') }
$launcherConfig | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $launcherDirectory 'launcher.json') -Encoding utf8
Write-Output 'FurniForge background launcher configured. Sign in to Codex CLI with your own account before use.'
