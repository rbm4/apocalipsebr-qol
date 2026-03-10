<#
.SYNOPSIS
    Converts PZ translation files from legacy .txt (Lua tables) to .json for 42.15+.

.DESCRIPTION
    Project Zomboid 42.15 changed Translator.java to load translations exclusively
    from .json files.  The old Lua-table .txt format is no longer read - the engine
    silently skips missing .json files and getText() returns raw keys.

    Old:  media/lua/shared/Translate/EN/UI_EN.txt      UI_EN = { Key = "val", }
    New:  media/lua/shared/Translate/EN/UI.json         { "Key": "val" }

    This script recursively finds every Translate folder under the mods directory,
    parses each .txt file (Lua-table or flat key=value), and writes a .json file
    in the same language folder with the category-only name.

.PARAMETER ModsRoot
    Path to the mods directory.  Default: <script>\..\Contents\mods

.PARAMETER DryRun
    Preview what would be converted without writing any files.

.PARAMETER DeleteOld
    Delete original .txt files after successful conversion.  Default: keep them
    (the engine ignores .txt files so they cause no conflict).
#>
param(
    [string]$ModsRoot,
    [switch]$DryRun,
    [switch]$DeleteOld
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve mods root
# ---------------------------------------------------------------------------
if (-not $ModsRoot) {
    $ModsRoot = Join-Path $PSScriptRoot '..\Contents\mods'
}
$ModsRoot = (Resolve-Path $ModsRoot).Path

Write-Host "`n=== PZ Translation Converter (.txt -> .json) ===" -ForegroundColor Cyan
Write-Host "Scanning: $ModsRoot"
if ($DryRun) { Write-Host '[DRY RUN - no files will be written]' -ForegroundColor Yellow }
Write-Host ''

# ---------------------------------------------------------------------------
# Find all Translate directories
# ---------------------------------------------------------------------------
$translateDirs = Get-ChildItem -Path $ModsRoot -Directory -Recurse -Filter 'Translate'
$stats = @{ converted = 0; skipped = 0; errors = 0; empty = 0 }

# Regex: matches   Key = "Value",   with optional trailing comma / line comment
# Supports keys with word-chars, dots, and hyphens  (e.g. RM_a78b-..., DisplayName_Base.Axe)
# Value: standard double-quoted string with backslash escapes
$kvPattern = '^([\w.\-]+)\s*=\s*"((?:[^"\\]|\\.)*)"\s*,?\s*(?:--.*)?$'

foreach ($tDir in $translateDirs) {
    foreach ($langDir in (Get-ChildItem $tDir.FullName -Directory)) {
        $lang = $langDir.Name

        foreach ($txt in (Get-ChildItem $langDir.FullName -Filter '*.txt' -File)) {
            $base   = $txt.BaseName          # e.g. "UI_EN", "IG_UI_PTBR"
            $suffix = "_$lang"

            # Derive category by stripping the _{Language} suffix from the filename
            if ($base.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)) {
                $category = $base.Substring(0, $base.Length - $suffix.Length)
            } else {
                $category = $base
            }

            $jsonFile = Join-Path $langDir.FullName "$category.json"
            $rel      = $txt.FullName.Substring($ModsRoot.Length + 1)

            # Skip if .json already exists (previous run / manual file)
            if (Test-Path $jsonFile) {
                $stats.skipped++
                continue
            }

            try {
                $raw = [IO.File]::ReadAllText($txt.FullName, [Text.Encoding]::UTF8)

                # Strip /* ... */ block comments
                $raw = [regex]::Replace($raw, '/\*.*?\*/', '', 'Singleline')

                $entries = [ordered]@{}

                foreach ($line in ($raw -split '\r?\n')) {
                    $t = $line.Trim()

                    # Skip blank lines, line comments
                    if (-not $t)               { continue }
                    if ($t.StartsWith('--'))    { continue }
                    if ($t.StartsWith('//'))    { continue }

                    # Skip Lua table header  ( TableName = { )  and footer  ( } )
                    if ($t -match '^\w+\s*=\s*\{') { continue }
                    if ($t -match '^\}\s*;?\s*$')   { continue }

                    # Extract key = "value"
                    if ($t -match $kvPattern) {
                        $entries[$Matches[1]] = $Matches[2]
                    }
                }

                if ($entries.Count -eq 0) {
                    Write-Host "  EMPTY: $rel" -ForegroundColor DarkYellow
                    $stats.empty++
                    continue
                }

                # ----- Build JSON manually (avoids double-escaping issues) -----
                $sb = [Text.StringBuilder]::new(4096)
                [void]$sb.AppendLine('{')

                $keys = @($entries.Keys)
                for ($i = 0; $i -lt $keys.Count; $i++) {
                    $k     = $keys[$i]
                    $v     = $entries[$k]
                    $comma = if ($i -lt $keys.Count - 1) { ',' } else { '' }
                    # Use string concatenation to avoid format-operator issues with { } in values
                    [void]$sb.AppendLine('    "' + $k + '": "' + $v + '"' + $comma)
                }

                [void]$sb.Append('}')
                $json = $sb.ToString()

                if (-not $DryRun) {
                    $utf8NoBom = [Text.UTF8Encoding]::new($false)
                    [IO.File]::WriteAllText($jsonFile, $json, $utf8NoBom)

                    if ($DeleteOld) {
                        Remove-Item $txt.FullName -Force
                    }
                }

                Write-Host ('  OK ({0,3} keys): {1} -> {2}.json' -f $entries.Count, $rel, $category) -ForegroundColor Green
                $stats.converted++
            }
            catch {
                Write-Host "  ERROR: $rel - $($_.Exception.Message)" -ForegroundColor Red
                $stats.errors++
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Converted: $($stats.converted)" -ForegroundColor Green
Write-Host "  Skipped:   $($stats.skipped)"   -ForegroundColor Yellow
Write-Host "  Empty:     $($stats.empty)"      -ForegroundColor DarkYellow
$errColor = if ($stats.errors -gt 0) { 'Red' } else { 'Gray' }
Write-Host "  Errors:    $($stats.errors)"     -ForegroundColor $errColor

if (-not $DeleteOld -and -not $DryRun -and $stats.converted -gt 0) {
    Write-Host "`n  Old .txt files were kept (the engine ignores them)." -ForegroundColor Gray
    Write-Host '  Re-run with -DeleteOld to remove them.' -ForegroundColor Gray
}

Write-Host ''
