<#
Make Junk Files
https://github.com/cosmickatamari/cosmic-file-suite

Created by: cosmickatamari
Updated: 01/25/2026

Generates random junk files for bulk file testing. Names are loaded from an
external list (junk-names.txt) and can be comma-delimited or one-per-line.
#>

param(
    [switch]$Help,
    [string]$Target,
    [int]$FileNum
)
Set-StrictMode -Version Latest

function Write-Info {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor White
}

function Write-Warn {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Write-Summary {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor DarkCyan
}

function Write-Fail {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Write-MessageWithFlags {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [ConsoleColor]$FlagColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$ParenColor = [ConsoleColor]::Yellow
    )
    $parts = [regex]::Split($Text, '(\s-[A-Za-z0-9]+|\([^)]*\))')
    foreach ($part in $parts) {
        if ($part -eq '') {
            continue
        }
        if ($part -match '^(\s+)(-[A-Za-z0-9]+)$') {
            Write-Host $matches[1] -NoNewline -ForegroundColor $Color
            Write-Host $matches[2] -NoNewline -ForegroundColor $FlagColor
        } elseif ($part -match '^\([^)]*\)$') {
            Write-Host $part -NoNewline -ForegroundColor $ParenColor
        } else {
            Write-Host $part -NoNewline -ForegroundColor $Color
        }
    }
    Write-Host ""
}

function Format-PathInput {
    param([Parameter(Mandatory = $true)][string]$PathText)
    $trimmed = $PathText.Trim()
    if ($trimmed.Length -ge 2 -and $trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) {
        return $trimmed.Substring(1, $trimmed.Length - 2)
    }
    return $trimmed
}

function Read-DirectoryPath {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [switch]$CreateIfMissing
    )

    while ($true) {
        $prevColor = $Host.UI.RawUI.ForegroundColor
        Write-Host $Prompt -NoNewline -ForegroundColor White
        Write-Host " " -NoNewline -ForegroundColor White
        $inputPath = [Console]::ReadLine()
        $Host.UI.RawUI.ForegroundColor = $prevColor

        $inputPath = Format-PathInput $inputPath
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            Write-Info "Please enter a path."
            continue
        }

        if (-not (Test-Path -LiteralPath $inputPath)) {
            if ($CreateIfMissing) {
                New-Item -Path $inputPath -ItemType Directory -Force | Out-Null
            } else {
                Write-Warn "Path does not exist: $inputPath"
                continue
            }
        }

        $resolvedItem = Get-Item -LiteralPath $inputPath
        $resolved = $resolvedItem.FullName
        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            Write-Warn "Path is not a directory: $resolved"
            continue
        }
        return $resolved
    }
}

function Resolve-DirectoryPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$CreateIfMissing
    )

    $inputPath = Format-PathInput $Path
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        Write-Fail "Path cannot be empty."
    }

    if (-not (Test-Path -LiteralPath $inputPath)) {
        if ($CreateIfMissing) {
            New-Item -Path $inputPath -ItemType Directory -Force | Out-Null
        } else {
            Write-Fail "Path does not exist: $inputPath"
        }
    }

    $resolvedItem = Get-Item -LiteralPath $inputPath
    $resolved = $resolvedItem.FullName
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        Write-Fail "Path is not a directory: $resolved"
    }
    return $resolved
}

function Read-PositiveInt {
    param([Parameter(Mandatory = $true)][string]$Prompt)

    while ($true) {
        $prevColor = $Host.UI.RawUI.ForegroundColor
        Write-Host $Prompt -NoNewline -ForegroundColor White
        Write-Host " " -NoNewline -ForegroundColor White
        $inputValue = [Console]::ReadLine()
        $Host.UI.RawUI.ForegroundColor = $prevColor

        if ([int]::TryParse($inputValue, [ref]$null) -and [int]$inputValue -gt 0) {
            return [int]$inputValue
        }
        Write-Warn "Please enter a whole number greater than zero."
    }
}

function Get-NameListOrNull {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    $names = $raw -split "[,`r`n]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ }

    if ($names.Count -lt 1) {
        Write-Warn "Names file has no valid entries: $Path"
        return $null
    }

    return $names
}

function New-RandomKey {
    param([int]$Length = 8)
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $builder = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Length; $i++) {
        $index = Get-Random -Minimum 0 -Maximum $chars.Length
        [void]$builder.Append($chars[$index])
    }
    return $builder.ToString()
}

function New-JunkFiles {
    param(
        [Parameter(Mandatory = $true)][string]$TargetDirectory,
        [Parameter(Mandatory = $true)][int]$FileCount,
        [string[]]$NameList,
        [switch]$UseRandomFallback
    )

    if ($UseRandomFallback) {
        Write-Warn "junk-names.txt not found. Using random 8-character names."
    }
    $useSingleFallback = $false
    if (-not $UseRandomFallback -and $NameList.Count -eq 1) {
        Write-Warn "Only one name found. Filling in with random 8-character names."
        $useSingleFallback = $true
    }
    Write-Info "Generating random junk files ..."

    for ($i = 1; $i -le $FileCount; $i++) {
        if ($UseRandomFallback) {
            $randomFileName = "$(New-RandomKey 8)_$(New-RandomKey 8).txt"
        } elseif ($useSingleFallback) {
            $word1 = $NameList[0]
            $word2 = New-RandomKey 8
            $randomFileName = "$word1`_$word2.txt"
        } else {
            $word1 = Get-Random -InputObject $NameList
            $word2 = Get-Random -InputObject $NameList
            $randomFileName = "$word1`_$word2.txt"
        }
        $filePath = Join-Path -Path $TargetDirectory -ChildPath $randomFileName
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        Set-Content -Path $filePath -Value "File created on $timestamp"
    }

    Write-Summary "$FileCount dummy files with timestamp created in $TargetDirectory"
}

function Show-Help {
    Clear-Host
    Write-Host "=== [ cosmickatamari's Junk File Generator ]===" -ForegroundColor Blue
    Write-Host "=== [ Version 2026.2 ] ===`n" -ForegroundColor Blue

    Write-Info "Generates randomized junk files for bulk file testing."
    Write-Host "Names are loaded from an external list (" -NoNewline -ForegroundColor White
    Write-Host "junk-names.txt" -NoNewline -ForegroundColor Yellow
    Write-Host ").`n" -ForegroundColor White

    Write-Host "Flags:" -ForegroundColor DarkYellow
    Write-MessageWithFlags "  -Help        Show this help document."

    Write-Host "`nParameters:" -ForegroundColor DarkYellow
    Write-MessageWithFlags "  -Target  <path>  Destination folder for generated files."
    Write-MessageWithFlags "  -FileNum <int>   Number of files to generate."
    Write-Host "                   If any parameter is not provided, the script prompts for it." -ForegroundColor DarkMagenta

    Write-Host "`nNotes:" -ForegroundColor DarkYellow
    Write-MessageWithFlags "  Each file contains a timestamp so it is not zero bytes."
    Write-MessageWithFlags "  Large batches of zero byte files can cause Explorer to freeze or crash."
    Write-MessageWithFlags "  The target directory is created if it does not exist."
    Write-Host "  If " -NoNewline -ForegroundColor White
    Write-Host "junk-names.txt" -NoNewline -ForegroundColor Yellow
    Write-Host " is missing, random 8-character names are used." -ForegroundColor White
    Write-Host "  " -NoNewline -ForegroundColor White
    Write-Host "junk-names.txt" -NoNewline -ForegroundColor Yellow
    Write-Host " supports comma-delimited or one-per-line entries." -ForegroundColor White

    Write-Host "`nExamples:" -ForegroundColor DarkYellow
    Write-MessageWithFlags "  .\make-junk-files.ps1 -Help"
    Write-MessageWithFlags "  .\make-junk-files.ps1"
    Write-MessageWithFlags "  .\make-junk-files.ps1 -Target D:\Temp -FileNum 500"
    Write-MessageWithFlags "  .\make-junk-files.ps1 -Target D:\Temp -FileNum 1000`n"
    exit 0
}

if ($Help) {
    Show-Help
}

Write-Host ""
Write-Host "=== [ cosmickatamari's Junk File Generator ]===" -ForegroundColor Blue
Write-Host "=== [ Version 2026.2 ] ===" -ForegroundColor Blue
Write-Host ""

$targetResolved = if ($Target) {
    Resolve-DirectoryPath -Path $Target -CreateIfMissing
} else {
    Read-DirectoryPath -Prompt "Enter the target folder for junk files:" -CreateIfMissing
}

$countResolved = if ($FileNum -gt 0) {
    $FileNum
} else {
    Read-PositiveInt -Prompt "Enter number of files to generate:"
}

if ($countResolved -gt 1000) {
    $prevColor = $Host.UI.RawUI.ForegroundColor
    Write-Host "You are about to generate " -NoNewline -ForegroundColor White
    Write-Host $countResolved -NoNewline -ForegroundColor Yellow
    Write-Host " files. Continue?" -NoNewline -ForegroundColor White
    Write-Host " (Y/N) [N] " -NoNewline -ForegroundColor Cyan
    $answer = [Console]::ReadLine().Trim()
    $Host.UI.RawUI.ForegroundColor = $prevColor
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer -notmatch '^(y|yes)$') {
        Write-Info "Operation cancelled."
        exit 0
    }
}

$namesFilePath = Join-Path $PSScriptRoot "junk-names.txt"
$nameList = Get-NameListOrNull -Path $namesFilePath
$useFallback = $null -eq $nameList
New-JunkFiles -TargetDirectory $targetResolved -FileCount $countResolved -NameList $nameList -UseRandomFallback:$useFallback
