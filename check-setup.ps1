# Read-only local prerequisite check; does not read credentials or modify configuration.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$node = Get-Command node -ErrorAction SilentlyContinue | Select-Object -First 1
$codex = Get-Command codex -ErrorAction SilentlyContinue | Select-Object -First 1
Write-Output 'FurniForge prerequisite check (Windows)'
if ($node) { Write-Output ('Node: ' + $node.Source); & $node.Source --version } else { Write-Output 'Node: not found on PATH (Node.js 20+ required).' }
if ($codex) { Write-Output ('Codex command found: ' + $codex.Source) } else { Write-Output 'Codex command: not found on PATH; a native codex.exe path can be supplied during setup.' }
if (Test-Path -LiteralPath (Join-Path $root 'server/index.mjs') -PathType Leaf) { Write-Output 'MCP server source: found.' } else { Write-Output 'MCP server source: missing.' }
if (Test-Path -LiteralPath (Join-Path $root 'node_modules/@modelcontextprotocol/sdk/package.json') -PathType Leaf) { Write-Output 'MCP dependency: found.' } else { Write-Output 'MCP dependency: missing; run npm ci --ignore-scripts in the extracted repository.' }
$launcher = Join-Path $env:LOCALAPPDATA 'FurniForge/launcher.json'
if (Test-Path -LiteralPath $launcher -PathType Leaf) { Write-Output 'Launcher configuration: file exists (paths and sign-in have not been verified).' } else { Write-Output 'Launcher configuration: not found; use setup-launcher.ps1 after installing prerequisites.' }
$state = Join-Path $env:LOCALAPPDATA 'FurniForge/bridge.json'
if (Test-Path -LiteralPath $state -PathType Leaf) { Write-Output 'Bridge state file: exists; this does not verify a live connection.' } else { Write-Output 'Bridge state file: not found; open SketchUp and start FurniForge.' }
Write-Output 'For a live check, call furniforge_status through the configured MCP client. This script does not check account sign-in.'
