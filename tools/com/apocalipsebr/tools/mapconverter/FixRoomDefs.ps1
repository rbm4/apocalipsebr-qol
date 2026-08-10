param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [ValidateSet("Native", "GenerateLots", "Editor", "Tile")]
    [string]$Mode = "Native"
)

$ErrorActionPreference = "Stop"

$cellsDir = Join-Path $ProjectDir "cells"
if (!(Test-Path -LiteralPath $cellsDir)) {
    throw "Cells directory not found: $cellsDir"
}

$fixedObjects = 0
$removedObjects = 0
$fixedXmlNames = 0

function Repair-UnescapedAmpersands {
    param([string]$Path)

    $text = Get-Content -LiteralPath $Path -Raw
    $before = $text

    # Known PZ tilesets with raw ampersands in their tileset names.
    $text = $text.Replace('name="trash&junk_01"', 'name="trash&amp;junk_01"')
    $text = $text.Replace('name="books&misc_01"', 'name="books&amp;misc_01"')

    if ($text -ne $before) {
        Set-Content -LiteralPath $Path -Value $text -NoNewline -Encoding UTF8
        $script:fixedXmlNames++
    }
}

function Get-PropertyMap {
    param([System.Xml.XmlElement]$ObjectNode)

    $props = @{}
    foreach ($p in $ObjectNode.SelectNodes("properties/property")) {
        $props[$p.GetAttribute("name")] = $p.GetAttribute("value")
    }
    return $props
}

function Normalize-ObjectRect {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$Prefix
    )

    $props = Get-PropertyMap $ObjectNode

    if ($props.ContainsKey("${Prefix}TileX")) {
        $x = [int][double]$props["${Prefix}TileX"]
        $y = [int][double]$props["${Prefix}TileY"]
        $w = [int][double]$props["${Prefix}TileW"]
        $h = [int][double]$props["${Prefix}TileH"]
    } else {
        $x = [int][double]$ObjectNode.GetAttribute("x")
        $y = [int][double]$ObjectNode.GetAttribute("y")
        $w = [int][double]$ObjectNode.GetAttribute("width")
        $h = [int][double]$ObjectNode.GetAttribute("height")

        # Earlier/native exports write TMX object rectangles in pixels.
        if ($x -gt 256 -or $y -gt 256 -or $w -gt 256 -or $h -gt 256) {
            $x = [int][Math]::Round($x / 64.0)
            $y = [int][Math]::Round($y / 32.0)
            $w = [int][Math]::Round($w / 64.0)
            $h = [int][Math]::Round($h / 32.0)
        }
    }

    $x1 = [Math]::Max(0, $x)
    $y1 = [Math]::Max(0, $y)
    $x2 = [Math]::Min(256, $x + $w)
    $y2 = [Math]::Min(256, $y + $h)

    if ($x1 -ge $x2 -or $y1 -ge $y2) {
        return $null
    }

    if ($Mode -eq "Native" -or $Mode -eq "GenerateLots" -or $Mode -eq "Editor") {
        return @{
            X = $x1 * 64
            Y = $y1 * 32
            W = ($x2 - $x1) * 64
            H = ($y2 - $y1) * 32
        }
    }

    return @{
        X = $x1
        Y = $y1
        W = $x2 - $x1
        H = $y2 - $y1
    }
}

function Get-CellName {
    param([string]$Path)
    return [IO.Path]::GetFileNameWithoutExtension($Path)
}

function Safe-PathPart {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "room" }
    $s = $Value -replace '[^A-Za-z0-9_-]+', '_'
    if ([string]::IsNullOrWhiteSpace($s)) { return "room" }
    return $s
}

function Set-NativeRoomType {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$CellName,
        [int]$Level,
        [hashtable]$Rect,
        [int]$Index
    )

    if ($Mode -ne "Native" -and $Mode -ne "GenerateLots" -and $Mode -ne "Editor") { return }

    $roomName = $ObjectNode.GetAttribute("name")
    if ([string]::IsNullOrWhiteSpace($roomName)) { $roomName = "room" }

    $tileX = [int][Math]::Round($Rect.X / 64.0)
    $tileY = [int][Math]::Round($Rect.Y / 32.0)
    $safeName = Safe-PathPart $roomName
    $ObjectNode.SetAttribute("type", ".\tbx\$CellName\${CellName}_${Level}_${safeName}_${tileX}_${tileY}_${Index}.tbx")
}

Get-ChildItem -LiteralPath $cellsDir -Filter *.tmx | ForEach-Object {
    Repair-UnescapedAmpersands $_.FullName
    $cellName = Get-CellName $_.FullName

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($_.FullName)

    $changed = $false
    $remove = New-Object System.Collections.Generic.List[System.Xml.XmlNode]

    foreach ($group in $doc.SelectNodes('//objectgroup[contains(@name,"RoomDefs")]')) {
        $oldName = $group.GetAttribute("name")
        $group.SetAttribute("name", "RoomDefs")
        if (!$group.HasAttribute("level")) {
            if ($oldName -match '^(-?\d+)_') { $group.SetAttribute("level", $matches[1]) } else { $group.SetAttribute("level", "0") }
        }
        $group.SetAttribute("width", "256")
        $group.SetAttribute("height", "256")
        if ($group.HasAttribute("color")) { $group.RemoveAttribute("color") }
        $changed = $true
    }

    $roomIndex = 0
    foreach ($o in $doc.SelectNodes('//object[ancestor::objectgroup[@name="RoomDefs"]]')) {
        $rect = Normalize-ObjectRect $o "Room"
        if ($null -eq $rect) {
            $remove.Add($o)
            $removedObjects++
            $changed = $true
            continue
        }

        if ($o.GetAttribute("x") -ne [string]$rect.X -or
            $o.GetAttribute("y") -ne [string]$rect.Y -or
            $o.GetAttribute("width") -ne [string]$rect.W -or
            $o.GetAttribute("height") -ne [string]$rect.H) {
            $o.SetAttribute("x", [string]$rect.X)
            $o.SetAttribute("y", [string]$rect.Y)
            $o.SetAttribute("width", [string]$rect.W)
            $o.SetAttribute("height", [string]$rect.H)
            $fixedObjects++
            $changed = $true
        }
        $level = [int]$o.ParentNode.GetAttribute("level")
        Set-NativeRoomType $o $cellName $level $rect $roomIndex
        $roomIndex++
    }

    foreach ($o in $doc.SelectNodes('//object[@type="building"]')) {
        $rect = Normalize-ObjectRect $o "Building"
        if ($null -eq $rect) {
            $remove.Add($o)
            $removedObjects++
            $changed = $true
            continue
        }

        if ($o.GetAttribute("x") -ne [string]$rect.X -or
            $o.GetAttribute("y") -ne [string]$rect.Y -or
            $o.GetAttribute("width") -ne [string]$rect.W -or
            $o.GetAttribute("height") -ne [string]$rect.H) {
            $o.SetAttribute("x", [string]$rect.X)
            $o.SetAttribute("y", [string]$rect.Y)
            $o.SetAttribute("width", [string]$rect.W)
            $o.SetAttribute("height", [string]$rect.H)
            $fixedObjects++
            $changed = $true
        }
    }

    foreach ($node in $remove) {
        [void]$node.ParentNode.RemoveChild($node)
    }

    if ($changed) {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
        $settings.Indent = $false
        $writer = [System.Xml.XmlWriter]::Create($_.FullName, $settings)
        $doc.Save($writer)
        $writer.Close()
    }
}

$bad = @()
Get-ChildItem -LiteralPath $cellsDir -Filter *.tmx | ForEach-Object {
    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($_.FullName)
    foreach ($o in $doc.SelectNodes('//object[@type="room" or @type="building"]')) {
        $x = [double]$o.GetAttribute("x")
        $y = [double]$o.GetAttribute("y")
        $w = [double]$o.GetAttribute("width")
        $h = [double]$o.GetAttribute("height")
        if ($Mode -eq "Native" -or $Mode -eq "GenerateLots" -or $Mode -eq "Editor") {
            $x = [Math]::Round($x / 64.0)
            $y = [Math]::Round($y / 32.0)
            $w = [Math]::Round($w / 64.0)
            $h = [Math]::Round($h / 32.0)
        }

        if ($x -lt 0 -or $y -lt 0 -or ($x + $w) -gt 256 -or ($y + $h) -gt 256) {
            $bad += "$($_.Name): $($o.GetAttribute("name")) x=$x y=$y w=$w h=$h"
        }
    }
}

Write-Host "Fixed object rectangles: $fixedObjects"
Write-Host "Removed out-of-cell objects: $removedObjects"
Write-Host "Fixed tileset XML names: $fixedXmlNames"

if ($bad.Count -gt 0) {
    Write-Host "Boundary validation FAILED:" -ForegroundColor Red
    $bad | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Mode: $Mode"
Write-Host "Boundary validation OK: no room/building object crosses 0..256 tile bounds." -ForegroundColor Green
