<#
.SYNOPSIS
    Trelai Map Tools - Compile and run map conversion or tile replacement tools.
.DESCRIPTION
    Interactive menu to run:
      1) Full B41→B42 map conversion (ConvertMap)
      2) Tile name replacement (LotpackStrings --replace)
      3) Dump all tile names (LotpackStrings --dump)
      4) Regenerate worldmap.xml.bin only (ConvertMap --gen-bin)
#>

$ErrorActionPreference = "Stop"

# ── Paths ──
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent | Split-Path -Parent
$repoRoot    = Split-Path -Parent $toolsDir
$mapDir      = Join-Path $repoRoot "Contents\mods\Trelai_4x4_Steam\common\media\maps\Trelai_4x4"
$backupDir   = Join-Path $repoRoot "Contents\mods\Trelai_4x4_Steam\common\media\maps\Trelai_4x4_backup"
$csvFile     = Join-Path $PSScriptRoot "tile_replacements.csv"
$srcDir      = Join-Path $toolsDir "com\apocalipsebr\tools\mapconverter"
$pkg         = "com.apocalipsebr.tools.mapconverter"

# ── Functions ──

function Compile-Sources {
    Write-Host "`n Compiling Java sources..." -ForegroundColor Cyan
    Push-Location $toolsDir
    $sources = @(
        "com\apocalipsebr\tools\mapconverter\ConvertMap.java",
        "com\apocalipsebr\tools\mapconverter\LotpackStrings.java",
        "com\apocalipsebr\tools\mapconverter\LotpackEditor.java",
        "com\apocalipsebr\tools\mapconverter\VerifyBin.java"
    )
    & javac -encoding UTF-8 @sources
    if ($LASTEXITCODE -ne 0) {
        Pop-Location
        Write-Host " Compilation FAILED!" -ForegroundColor Red
        return $false
    }
    Pop-Location
    Write-Host " Compilation OK" -ForegroundColor Green
    return $true
}

function Run-Java {
    param([string]$class, [string[]]$arguments)
    Push-Location $toolsDir
    Write-Host "`n Running: $class $($arguments -join ' ')" -ForegroundColor Yellow
    Write-Host ("-" * 60)
    & java -cp . "$pkg.$class" @arguments
    $code = $LASTEXITCODE
    Write-Host ("-" * 60)
    if ($code -ne 0) {
        Write-Host " Exit code: $code" -ForegroundColor Red
    } else {
        Write-Host " Done." -ForegroundColor Green
    }
    Pop-Location
    return $code
}

function Show-Menu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "       Trelai Map Tools" -ForegroundColor White
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Full B41 -> B42 Map Conversion" -ForegroundColor White
    Write-Host "      (backup -> output, lotheader + lotpack + chunkdata + worldmap.bin)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [2] Replace Broken Tile Names" -ForegroundColor White
    Write-Host "      (reads tile_replacements.csv, patches .lotheader files)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [3] Dump All Tile Names" -ForegroundColor White
    Write-Host "      (lists every unique tile name from .lotheader files)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [4] Regenerate worldmap.xml.bin Only" -ForegroundColor White
    Write-Host "      (re-generates .bin from existing worldmap.xml)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [5] Verify worldmap.xml.bin" -ForegroundColor White
    Write-Host "      (validates binary format)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  --- Lotpack Editor ---" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [6] Inspect Cell / Chunk" -ForegroundColor White
    Write-Host "      (list all objects in a cell, or detailed for one chunk)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [7] Inspect At Coordinate" -ForegroundColor White
    Write-Host "      (show all objects stacked at a world x,y,z)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [8] Search Tile in Cell" -ForegroundColor White
    Write-Host "      (find every square containing a specific tile name)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [9] Remove Object" -ForegroundColor White
    Write-Host "      (delete a tile object at a world coordinate)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [A] Set Object (swap tile)" -ForegroundColor White
    Write-Host "      (change a tile to a different one at a coordinate)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [B] Add Object" -ForegroundColor White
    Write-Host "      (place a new tile object at a coordinate)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [C] Apply Patch File" -ForegroundColor White
    Write-Host "      (batch add/remove/set from CSV; optional worldmap.xml sync)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor DarkGray
    Write-Host ""
}

# ── Main Loop ──

do {
    Show-Menu
    $choice = Read-Host "Select an option"

    switch ($choice.Trim().ToUpper()) {
        "1" {
            Write-Host "`n=== Full B41 -> B42 Map Conversion ===" -ForegroundColor Cyan
            Write-Host "  Input:  $backupDir" -ForegroundColor DarkGray
            Write-Host "  Output: $mapDir" -ForegroundColor DarkGray
            if (!(Compile-Sources)) { break }
            Run-Java "ConvertMap" @($backupDir, $mapDir)
            # Auto-verify the generated bin
            $bin = Join-Path $mapDir "worldmap.xml.bin"
            if (Test-Path $bin) {
                Write-Host "`n Verifying worldmap.xml.bin..." -ForegroundColor Cyan
                Run-Java "VerifyBin" @($bin)
            }
        }
        "2" {
            Write-Host "`n=== Replace Broken Tile Names ===" -ForegroundColor Cyan
            Write-Host "  CSV:    $csvFile" -ForegroundColor DarkGray
            Write-Host "  Target: $mapDir" -ForegroundColor DarkGray
            if (!(Test-Path $csvFile)) {
                Write-Host " CSV file not found: $csvFile" -ForegroundColor Red
                break
            }
            if (!(Compile-Sources)) { break }
            Run-Java "LotpackStrings" @("--replace", $mapDir, $csvFile)
        }
        "3" {
            Write-Host "`n=== Dump All Tile Names ===" -ForegroundColor Cyan
            Write-Host "  Target: $mapDir" -ForegroundColor DarkGray
            if (!(Compile-Sources)) { break }
            Run-Java "LotpackStrings" @("--dump", $mapDir)
        }
        "4" {
            Write-Host "`n=== Regenerate worldmap.xml.bin ===" -ForegroundColor Cyan
            Write-Host "  Target: $mapDir" -ForegroundColor DarkGray
            if (!(Compile-Sources)) { break }
            Run-Java "ConvertMap" @("--gen-bin", $mapDir)
        }
        "5" {
            Write-Host "`n=== Verify worldmap.xml.bin ===" -ForegroundColor Cyan
            $bin = Join-Path $mapDir "worldmap.xml.bin"
            if (!(Test-Path $bin)) {
                Write-Host " File not found: $bin" -ForegroundColor Red
                break
            }
            if (!(Compile-Sources)) { break }
            Run-Java "VerifyBin" @($bin)
        }
        "6" {
            Write-Host "`n=== Inspect Cell / Chunk ===" -ForegroundColor Cyan
            Write-Host "  Map: $mapDir" -ForegroundColor DarkGray
            $cellCoords = Read-Host "Cell coords (e.g. 24_25)"
            $chunkCoords = Read-Host "Chunk filter (e.g. 15,20) or Enter for summary"
            if (!(Compile-Sources)) { break }
            $javaArgs = @("--inspect", $mapDir, $cellCoords)
            if ($chunkCoords.Trim() -ne "") { $javaArgs += $chunkCoords.Trim() }
            Run-Java "LotpackEditor" $javaArgs
        }
        "7" {
            Write-Host "`n=== Inspect At Coordinate ===" -ForegroundColor Cyan
            Write-Host "  Map: $mapDir" -ForegroundColor DarkGray
            $worldX = Read-Host "World X"
            $worldY = Read-Host "World Y"
            $z = Read-Host "Z level (default 0)"
            if ($z.Trim() -eq "") { $z = "0" }
            if (!(Compile-Sources)) { break }
            Run-Java "LotpackEditor" @("--inspect-at", $mapDir, $worldX, $worldY, $z)
        }
        "8" {
            Write-Host "`n=== Search Tile in Cell ===" -ForegroundColor Cyan
            Write-Host "  Map: $mapDir" -ForegroundColor DarkGray
            $cellCoords = Read-Host "Cell coords (e.g. 24_25)"
            $tileName = Read-Host "Tile name to search"
            if (!(Compile-Sources)) { break }
            Run-Java "LotpackEditor" @("--search", $mapDir, $cellCoords, $tileName)
        }
        "9" {
            Write-Host "`n=== Remove Object ===" -ForegroundColor Cyan
            Write-Host "  Map: $mapDir" -ForegroundColor DarkGray
            $worldX = Read-Host "World X"
            $worldY = Read-Host "World Y"
            $z = Read-Host "Z level (default 0)"
            if ($z.Trim() -eq "") { $z = "0" }
            $tileName = Read-Host "Tile name to remove"
            if (!(Compile-Sources)) { break }
            Run-Java "LotpackEditor" @("--remove", $mapDir, $worldX, $worldY, $z, $tileName)
        }
        "A" {
            Write-Host "`n=== Set Object (Swap Tile) ===" -ForegroundColor Cyan
            Write-Host "  Map: $mapDir" -ForegroundColor DarkGray
            $worldX = Read-Host "World X"
            $worldY = Read-Host "World Y"
            $z = Read-Host "Z level (default 0)"
            if ($z.Trim() -eq "") { $z = "0" }
            $oldTile = Read-Host "Current tile name"
            $newTile = Read-Host "New tile name"
            if (!(Compile-Sources)) { break }
            Run-Java "LotpackEditor" @("--set", $mapDir, $worldX, $worldY, $z, $oldTile, $newTile)
        }
        "B" {
            Write-Host "`n=== Add Object ===" -ForegroundColor Cyan
            Write-Host "  Map: $mapDir" -ForegroundColor DarkGray
            $worldX = Read-Host "World X"
            $worldY = Read-Host "World Y"
            $z = Read-Host "Z level (default 0)"
            if ($z.Trim() -eq "") { $z = "0" }
            $tileName = Read-Host "Tile name to add"
            if (!(Compile-Sources)) { break }
            Run-Java "LotpackEditor" @("--add", $mapDir, $worldX, $worldY, $z, $tileName)
        }
        "C" {
            Write-Host "`n=== Apply Patch File ===" -ForegroundColor Cyan
            $patchPath = Read-Host "Patch CSV file path"
            if (!(Test-Path $patchPath)) {
                Write-Host " File not found: $patchPath" -ForegroundColor Red
                break
            }
            $worldmapPath = Read-Host "Worldmap XML path (Enter to skip worldmap sync)"
            if (!(Compile-Sources)) { break }
            $javaArgs = @("--patch", $mapDir, $patchPath)
            if ($worldmapPath.Trim() -ne "" -and (Test-Path $worldmapPath)) {
                $javaArgs += $worldmapPath
            } elseif ($worldmapPath.Trim() -ne "") {
                Write-Host " Worldmap file not found: $worldmapPath - skipping sync" -ForegroundColor Yellow
            }
            Run-Java "LotpackEditor" $javaArgs
        }
        "Q" {
            Write-Host "`nBye!" -ForegroundColor Cyan
            return
        }
        default {
            Write-Host " Invalid option." -ForegroundColor Red
        }
    }

    Write-Host ""
    Read-Host "Press Enter to continue"
} while ($true)
