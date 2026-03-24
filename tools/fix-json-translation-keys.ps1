<#
.SYNOPSIS
    Fixes ItemName.json translation files for PZ 42.15+ compatibility.

.DESCRIPTION
    In PZ 42.15+, JSON translation files derive the category from the filename.
    For ItemName.json, keys must NOT include the "ItemName_" prefix.

    Old (broken):  "ItemName_ATA2.ATAProtectionWheelsChain": "Chain"
    New (correct):  "ATA2.ATAProtectionWheelsChain": "Chain"

    This script scans a Translate folder (containing language subfolders like EN, ES, etc.)
    and fixes all ItemName.json files by stripping the "ItemName_" prefix from keys.

.PARAMETER TranslateFolder
    Path to the Translate folder containing language subfolders (EN, ES, PTBR, etc.)

.PARAMETER DryRun
    If set, only reports what would be changed without modifying files.

.EXAMPLE
    .\fix-json-translation-keys.ps1 -TranslateFolder "C:\mods\tsarslib\42.14\media\lua\shared\Translate"
    .\fix-json-translation-keys.ps1 -TranslateFolder "C:\mods\tsarslib\common\media\lua\shared\Translate" -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TranslateFolder,

    [switch]$DryRun
)

if (-not (Test-Path $TranslateFolder)) {
    Write-Error "Folder not found: $TranslateFolder"
    exit 1
}

$jsonFiles = Get-ChildItem -Path $TranslateFolder -Recurse -Filter "ItemName.json"

if ($jsonFiles.Count -eq 0) {
    Write-Host "No ItemName.json files found under: $TranslateFolder" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($jsonFiles.Count) ItemName.json file(s) to process." -ForegroundColor Cyan
Write-Host ""

$totalFixed = 0

foreach ($file in $jsonFiles) {
    $relativePath = $file.FullName.Substring($TranslateFolder.TrimEnd('\', '/').Length + 1)
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8

    $json = $content | ConvertFrom-Json
    $properties = $json.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }

    $fixedCount = 0
    $newJson = [ordered]@{}

    foreach ($prop in $properties) {
        $key = $prop.Name
        $value = $prop.Value

        if ($key -match '^ItemName_(.+)$') {
            $newKey = $Matches[1]
            $newJson[$newKey] = $value
            $fixedCount++
        }
        else {
            $newJson[$key] = $value
        }
    }

    if ($fixedCount -eq 0) {
        Write-Host "  [OK] $relativePath - no prefixed keys found, already correct." -ForegroundColor Green
        continue
    }

    $totalFixed += $fixedCount

    if ($DryRun) {
        Write-Host "  [DRY-RUN] $relativePath - would fix $fixedCount key(s)." -ForegroundColor Yellow
    }
    else {
        $outputJson = $newJson | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($file.FullName, $outputJson, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  [FIXED] $relativePath - fixed $fixedCount key(s)." -ForegroundColor Green
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry run complete. $totalFixed key(s) across $($jsonFiles.Count) file(s) would be fixed." -ForegroundColor Cyan
}
else {
    Write-Host "Done. Fixed $totalFixed key(s) across $($jsonFiles.Count) file(s)." -ForegroundColor Cyan
}
