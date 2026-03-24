<#
.SYNOPSIS
    Adds 'repairMechanic = true,' after every 'durability = X,' line in vehicle template files
    that don't already have it, for parts that are repairable body/structural components.

.DESCRIPTION
    Scans all template_*.txt files under Contents/mods/*/media/scripts/vehicles/ (and versioned folders)
    and inserts 'repairMechanic = true,' on the line after each 'durability = X,' line,
    preserving the original indentation. 
    
    Skips:
    - Lines where repairMechanic already exists on the next line
    - Files for seats, tires, suspension, passengers (by filename)
    - Part blocks for spare tires, gas cans, generators, tents, consoles (by part name context)

.PARAMETER DryRun
    If specified, only reports what would be changed without modifying files.
#>
param(
    [switch]$DryRun
)

$rootDir = Split-Path $PSScriptRoot -Parent
$modsDir = Join-Path $rootDir "Contents\mods"

$totalFilesChanged = 0
$totalInsertions = 0
$totalSkipped = 0
$fileDetails = @()

# Files to completely skip (by filename pattern) - these part types should never get repairMechanic
$skipFilePatterns = @(
    '_seats\.txt$',
    '_tire\.txt$',
    '_tires\.txt$',
    '_armored_tire\.txt$',
    '_suspension\.txt$',
    '_passengers\.txt$'
)

# Part names to skip (spare tires, gas cans, generators, tents, consoles)
# These are detected by scanning backwards from the durability line to find the part name
$skipPartPatterns = @(
    'SpareTire',
    'DAMNGasCan',
    'DAMNGenerator',
    'DAMNTent',
    'KI5TRGasCan',
    'Console'
)

function Get-CurrentPartName {
    param([string[]]$Lines, [int]$CurrentIndex)
    # Scan backwards from durability line to find the enclosing "part <Name>" or template declaration
    for ($j = $CurrentIndex - 1; $j -ge 0; $j--) {
        if ($Lines[$j] -match '^\s*part\s+(\S+)') {
            return $Matches[1]
        }
        if ($Lines[$j] -match '^\s*template\s+vehicle\s+(\S+)') {
            return $Matches[1]
        }
    }
    return ""
}

function Test-PartHasRepairMechanic {
    param([string[]]$Lines, [int]$DurabilityIndex)
    # Scan backwards to find "part <Name>" line (start of block)
    $start = 0
    for ($j = $DurabilityIndex - 1; $j -ge 0; $j--) {
        if ($Lines[$j] -match '^\s*part\s+') {
            $start = $j
            break
        }
    }
    # Scan forward from part start to find closing "}" at the same or lesser indent, or next "part"
    $partIndent = ($Lines[$start] -match '^(\s*)') | Out-Null; $partIndentLen = $Matches[1].Length
    for ($j = $start; $j -lt $Lines.Count; $j++) {
        if ($Lines[$j] -match 'repairMechanic') {
            return $true
        }
        # Stop at next part declaration or closing brace at part level
        if ($j -gt $start -and $Lines[$j] -match '^\s*part\s+') {
            break
        }
        if ($j -gt $DurabilityIndex -and $Lines[$j] -match '^\s*\}' -and $Lines[$j].TrimStart().Length -le 2) {
            # Check if this closing brace is at or above the part level
            $braceIndent = ($Lines[$j] -match '^(\s*)') | Out-Null; $bi = $Matches[1].Length
            if ($bi -le $partIndentLen + 2) {
                break
            }
        }
    }
    return $false
}

# Find all template vehicle script files
$templateFiles = Get-ChildItem -Recurse -Filter "template_*.txt" -Path $modsDir |
    Where-Object { $_.FullName -match 'scripts[\\\/]vehicles' }

foreach ($file in $templateFiles) {
    # Check if file should be completely skipped
    $skipFile = $false
    foreach ($pattern in $skipFilePatterns) {
        if ($file.Name -match $pattern) {
            $skipFile = $true
            break
        }
    }
    if ($skipFile) { continue }

    $lines = Get-Content $file.FullName
    $newLines = [System.Collections.Generic.List[string]]::new()
    $insertions = 0
    $skipped = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $newLines.Add($line)

        # Check if this line has durability = X,
        if ($line -match '^(\s+)durability\s*=\s*\d+,') {
            $indent = $Matches[1]
            # Check if repairMechanic already exists anywhere in the same part block
            if (-not (Test-PartHasRepairMechanic -Lines $lines -DurabilityIndex $i)) {
                # Check if this part should be skipped by part name
                $partName = Get-CurrentPartName -Lines $lines -CurrentIndex $i
                $skipPart = $false
                foreach ($pattern in $skipPartPatterns) {
                    if ($partName -match $pattern) {
                        $skipPart = $true
                        break
                    }
                }
                if ($skipPart) {
                    $skipped++
                } else {
                    $newLines.Add("${indent}repairMechanic = true,")
                    $insertions++
                }
            }
        }
    }

    if ($insertions -gt 0 -or $skipped -gt 0) {
        $relativePath = $file.FullName.Replace($rootDir + "\", "")
        if ($insertions -gt 0) {
            $fileDetails += [PSCustomObject]@{
                File       = $relativePath
                Insertions = $insertions
                Skipped    = $skipped
                Action     = "PATCH"
            }
            $totalFilesChanged++
            $totalInsertions += $insertions
        }
        if ($skipped -gt 0) {
            $totalSkipped += $skipped
            if ($insertions -eq 0) {
                $fileDetails += [PSCustomObject]@{
                    File       = $relativePath
                    Insertions = 0
                    Skipped    = $skipped
                    Action     = "SKIP"
                }
            }
        }

        if ($insertions -gt 0 -and -not $DryRun) {
            Set-Content -Path $file.FullName -Value $newLines -Encoding UTF8 -NoNewline:$false
        }
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "=== DRY RUN - No files modified ===" -ForegroundColor Yellow
} else {
    Write-Host "=== CHANGES APPLIED ===" -ForegroundColor Green
}
Write-Host ""
Write-Host "Files changed: $totalFilesChanged"
Write-Host "Total insertions: $totalInsertions"
Write-Host "Total skipped: $totalSkipped (excluded part types)"
Write-Host ""

foreach ($detail in $fileDetails | Sort-Object File) {
    $marker = if ($detail.Action -eq "SKIP") { "SKIP" } else { "+$($detail.Insertions)" }
    $skipInfo = if ($detail.Skipped -gt 0 -and $detail.Action -eq "PATCH") { " (skipped $($detail.Skipped))" } else { "" }
    Write-Host "  [$marker] $($detail.File)$skipInfo"
}
