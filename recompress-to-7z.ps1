<#
Recompress to 7z
https://github.com/cosmickatamari/Recompress-To-7z
Created by: cosmickatamari
Updated: 01/16/2026

The purpose of this script is to take existing compressed files in various formats and recompress them into 7z archives using the Ultra setting to maximize space savings. The script first identifies non-7z archives and processes them accordingly. It then checks for existing 7z files in the specified source folder and prompts whether those archives should be recompressed, which is useful when the original compression method is unknown and additional space savings may be possible.

Depending on the parameters provided, the script can either replace the original compressed file with the new 7z archive or allow both files to coexist.
#>

param(
    [switch]$Help,
    [string]$Source,
    [string]$Temp,
    [string]$Dest,
	[switch]$FAT32,
    [switch]$CDRom,	
	[switch]$Skip,
    [switch]$Include,
    [switch]$Delete,
    [switch]$Replace,
    [switch]$Fast,
    [switch]$Recursive
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

function Write-FlagStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Enabled
    )
    Write-Host ("{0,-10}" -f $Name) -NoNewline -ForegroundColor White
    if ($Enabled) {
        Write-Host " is enabled." -ForegroundColor DarkCyan
    } else {
        Write-Host " was disabled." -ForegroundColor DarkGray
    }
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


function Read-YesNoDefaultNo {
    param([Parameter(Mandatory = $true)][string]$Prompt)
    while ($true) {
        $prevColor = $Host.UI.RawUI.ForegroundColor
        Write-Host $Prompt -NoNewline -ForegroundColor White
        Write-Host " (Y/N) [N] " -NoNewline -ForegroundColor Cyan
        $answer = [Console]::ReadLine().Trim()
        $Host.UI.RawUI.ForegroundColor = $prevColor
        if ([string]::IsNullOrWhiteSpace($answer)) {
            return $false
        }
        if ($answer -match '^(y|yes)$') {
            return $true
        }
        if ($answer -match '^(n|no)$') {
            return $false
        }
        Write-Warn "Please enter Y or N."
    }
}

function Read-SplitChoice {
    while ($true) {
        $prevColor = $Host.UI.RawUI.ForegroundColor
        Write-Host "For easier backup, should the archives be split? " -NoNewline -ForegroundColor White
        Write-Host "(N = None, C = 650mb, F = 4,000mb) [N] " -NoNewline -ForegroundColor Cyan
        $answer = [Console]::ReadLine().Trim()
        $Host.UI.RawUI.ForegroundColor = $prevColor
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^(n|no)$') {
            return 'None'
        }
        if ($answer -match '^(c|cdrom)$') {
            return 'CDROM'
        }
        if ($answer -match '^(f|fat32)$') {
            return 'FAT32'
        }
        Write-Warn "Please enter N, C, or F."
    }
}


function Read-DirectoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [switch]$CreateIfMissing
    )

    while ($true) {
        $inputPath = (Read-Host $Prompt).Trim()
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
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$CreateIfMissing
    )

    $inputPath = $Path.Trim()
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

function Get-RelativeSubPath {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $root = [System.IO.Path]::GetFullPath($RootPath)
    $full = [System.IO.Path]::GetFullPath($FullPath)

    if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $root += [System.IO.Path]::DirectorySeparatorChar
    }

    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $sub = $full.Substring($root.Length)
        return $sub.TrimStart([System.IO.Path]::DirectorySeparatorChar)
    }

    try {
        $rootUri = [System.Uri]($root.TrimEnd('\') + '\')
        $fullUri = [System.Uri]$full
        if ($rootUri.IsBaseOf($fullUri)) {
            $sub = $rootUri.MakeRelativeUri($fullUri).ToString()
            $sub = [System.Uri]::UnescapeDataString($sub) -replace '/', '\'
            if ($sub -eq '.' -or [string]::IsNullOrWhiteSpace($sub)) { return '' }
            return $sub.TrimStart([System.IO.Path]::DirectorySeparatorChar)
        }
        $sub = [System.IO.Path]::GetRelativePath($root, $full)
        if ($sub -eq '.') { return '' }
        return $sub.TrimStart([System.IO.Path]::DirectorySeparatorChar)
    } catch {
        return ''
    }
}

function Format-Argument {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -match '[\s"]') {
        return '"' + ($Value -replace '"', '\"') + '"'
    }
    return $Value
}

function Format-TextPreview {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$MaxLength
    )
    if ($MaxLength -le 0) {
        return ''
    }
    if ($Text.Length -le $MaxLength) {
        return $Text
    }
    if ($MaxLength -le 3) {
        return $Text.Substring(0, $MaxLength)
    }
    return $Text.Substring(0, $MaxLength - 3) + '...'
}

function Write-StatusLine {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][TimeSpan]$Elapsed
    )

    $elapsedText = $Elapsed.ToString('hh\:mm\:ss')
    $progressPrefix = "100% ($elapsedText) - ${Label} "

    $consoleWidth = 120
    try {
        $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    } catch {
        $consoleWidth = 120
    }

    $maxFileNameLength = [Math]::Max(8, $consoleWidth - $progressPrefix.Length)
    $fileNameDisplay = Format-TextPreview -Text $FileName -MaxLength $maxFileNameLength

    Write-Host "`r$progressPrefix" -NoNewline -ForegroundColor White
    Write-Host $fileNameDisplay -ForegroundColor DarkCyan
}

function Remove-ItemWithStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        Remove-Item -LiteralPath $Path -Recurse -Force
        $timer.Stop()
        Write-StatusLine -Label $Label -FileName (Split-Path -Leaf $Path) -Elapsed $timer.Elapsed
    } finally {
        $ProgressPreference = $prevProgress
    }
}

function Invoke-7zWithProgress {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$CaptureFileCount
    )

    $argString = ($Arguments | ForEach-Object { Format-Argument $_ }) -join ' '

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:SevenZipExe
    $psi.Arguments = $argString
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $lastPercent = 0
    $currentEntry = ''
    $lastLineLength = 0

    $render = {
        param([int]$Percent, [string]$Entry)
        $elapsed = $stopwatch.Elapsed.ToString('hh\:mm\:ss')
        $progressPrefix = "$Percent% ($elapsed) - ${Label} "
        $entryLabel = " | Entry: "
        $entryValue = if ([string]::IsNullOrWhiteSpace($Entry)) {
            "(initializing...)"
        } else {
            $Entry
        }

        $consoleWidth = 120
        try {
            $consoleWidth = $Host.UI.RawUI.WindowSize.Width
        } catch {
            $consoleWidth = 120
        }

        $minEntrySpace = 12
        $maxFileNameLength = [Math]::Max(8, $consoleWidth - ($progressPrefix.Length + $entryLabel.Length + $minEntrySpace))
        $fileNameDisplay = Format-TextPreview -Text $FileName -MaxLength $maxFileNameLength

        $maxEntryLength = [Math]::Max(0, $consoleWidth - ($progressPrefix.Length + $fileNameDisplay.Length + $entryLabel.Length))
        $entryDisplay = Format-TextPreview -Text $entryValue -MaxLength $maxEntryLength

        $lineLength = $progressPrefix.Length + $fileNameDisplay.Length + $entryLabel.Length + $entryDisplay.Length
        $pad = ' ' * [Math]::Max(0, $lastLineLength - $lineLength)

        Write-Host "`r$progressPrefix" -NoNewline -ForegroundColor White
        Write-Host $fileNameDisplay -NoNewline -ForegroundColor DarkCyan
        Write-Host "$entryLabel$entryDisplay$pad" -NoNewline -ForegroundColor Gray
        $lastLineLength = $lineLength
    }

    & $render 0 ''

    $process = [System.Diagnostics.Process]::Start($psi)

    $filesCount = $null
    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        if ($line -match '(\d{1,3})%') {
            $lastPercent = [int]$matches[1]
            & $render $lastPercent $currentEntry
        } elseif ($CaptureFileCount -and $line -match '^\s*Files:\s+(\d+)\s*$') {
            $filesCount = [int]$matches[1]
        } elseif (-not [string]::IsNullOrWhiteSpace($line)) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^(Extracting|Compressing|Updating)\s+(.+)$') {
                $currentEntry = $matches[2].Trim()
                & $render $lastPercent $currentEntry
            } elseif ($trimmed -notmatch '^(Scanning|Everything is Ok|Archive:|Creating|Folders:|Files:|Size:|Processed:|System:|Type:|Details:)') {
                $currentEntry = $trimmed
                & $render $lastPercent $currentEntry
            }
        }
    }

    $process.WaitForExit()
    $errorText = $process.StandardError.ReadToEnd()
    $stopwatch.Stop()
    if ($lastPercent -lt 100) {
        & $render 100 $currentEntry
    }
    Write-Host ""

    if ($process.ExitCode -ne 0) {
        if (-not [string]::IsNullOrWhiteSpace($errorText)) {
            Write-Host $errorText.Trim() -ForegroundColor Red
        }
        throw "7z failed for: $Label (exit code $($process.ExitCode))."
    }

    return $filesCount
}

function Format-Bytes {
    param([Parameter(Mandatory = $true)][long]$Bytes)
    $units = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    $size = [double]$Bytes
    $index = 0
    while ($size -ge 1024 -and $index -lt ($units.Count - 1)) {
        $size /= 1024
        $index++
    }
    return ('{0:N2} {1}' -f $size, $units[$index])
}

function Format-SizePair {
    param([Parameter(Mandatory = $true)][long]$Bytes)
    $gb = [double]$Bytes / 1GB
    $mb = [double]$Bytes / 1MB
    return ('{0:N2} GB ({1:N2} MB)' -f $gb, $mb)
}

function Show-Help {
	Clear-Host
    Write-Host "=== [ cosmickatamari's 7z Recompressor ]===" -ForegroundColor Blue
    Write-Host "=== [ Version 2026.1 ] ===`n" -ForegroundColor Blue
	
    Write-Info "Recompresses existing archives into 7z format with maximum compression."
    Write-Info "Extracts each archive to a temporary location, compresses to 7z archive, and removes temporary files.`n"
	
    Write-Host "Flags:" -ForegroundColor DarkYellow
    Write-MessageWithFlags "  -Help     	Show this help document."
    Write-MessageWithFlags "  -Skip     	Skip existing 7z files in the source folder without prompting."
    Write-MessageWithFlags "  -Include  	Always process 7z files in the source folder without prompting."
    Write-MessageWithFlags "  -Recursive	Include subfolders and preserve folder structure."
	Write-MessageWithFlags "  -Replace  	Delete the original source archive and move the new 7z into source folder."
    Write-MessageWithFlags "            	When -Replace is used and -Dest is passed, only -Source is used." -Color Yellow
    Write-MessageWithFlags "  -Delete   	Delete the original source archive after recompressing."
	Write-MessageWithFlags "  -FAT32    	Split 7z archive before FAT32 max file size 4,000mb is reached."
    Write-MessageWithFlags "  -CDROM    	Split 7z archive before 650mb file size is reached."
	Write-MessageWithFlags "  -Fast     	Skip fallback file counting for faster runs."
    Write-Host "            	Totals may be lower if 7-Zip doesn't report file counts.`n" -ForegroundColor Yellow
        
	Write-Host "Parameters:" -ForegroundColor DarkYellow
	Write-MessageWithFlags "  -Source <path>  Source folder containing compressed files."
	Write-MessageWithFlags "  -Temp   <path>  Temp extraction folder."
	Write-MessageWithFlags "  -Dest   <path>  Destination folder for 7z files."
	Write-MessageWithFlags "            	  If not provided, the script prompts for the missing path.`n"
    
	Write-Host "Notes:" -ForegroundColor DarkYellow
    Write-MessageWithFlags "  -Skip and -Include are mutually exclusive. If both are passed, default is -Skip."
    Write-MessageWithFlags "  -FAT32 and -CDROM are mutually exclusive. If both are passed, default is -CDROM."

    Write-MessageWithFlags "  -Replace implies -Delete."
	Write-MessageWithFlags "  -Fast skips fallback file counts when 7-Zip doesn't report totals.`n"
	
	Write-MessageWithFlags "  Without -Fast, the script scans extracted files to keep counts accurate."
	Write-Info "  If the temp or destination folder doesn't exist, it will be created."
    Write-Info "  The temp (extracted) files are deleted automatically after the new 7z archive is created.`n"
    
	Write-Host "Examples:" -ForegroundColor DarkYellow
    Write-MessageWithFlags "  .\Recompress-To-7z.ps1 -Help"
    Write-MessageWithFlags "  .\Recompress-To-7z.ps1 -Source D:\source -Temp D:\temp -Dest D:\newhome"
    Write-MessageWithFlags "  .\Recompress-To-7z.ps1 -Include -Source D:\source -Temp D:\temp -Dest D:\newhome"
    Write-MessageWithFlags "  .\Recompress-To-7z.ps1 -Replace -Skip -Source D:\source -Temp D:\temp -Dest D:\newhome"
	Write-MessageWithFlags "  .\Recompress-To-7z.ps1 -Replace -Include -FAT32 -Source D:\source -Temp D:\temp -Dest D:\newhome"
	Write-MessageWithFlags "  .\Recompress-To-7z.ps1 -Recursive -Replace -Include -Source D:\source -Temp D:\temp -Dest D:\newhome`n"
    exit 0
}

$script:SevenZipExe = 'C:\Program Files\7-Zip\7z.exe'
if (-not (Test-Path -LiteralPath $script:SevenZipExe)) {
    Write-Warn "7z.exe was not found at $script:SevenZipExe."
    Write-Info "Enter the full path to 7z.exe, or type Q to quit and open the download page."
    while ($true) {
        $prevColor = $Host.UI.RawUI.ForegroundColor
        $Host.UI.RawUI.ForegroundColor = 'White'
        $inputPath = (Read-Host "7z.exe path or Q").Trim()
        $Host.UI.RawUI.ForegroundColor = $prevColor
        if ($inputPath -match '^(q|quit)$') {
            Start-Process "https://www.7-zip.org/"
            exit 0
        }
        if (Test-Path -LiteralPath $inputPath) {
            $resolved = (Resolve-Path -LiteralPath $inputPath).Path
            if (Test-Path -LiteralPath $resolved -PathType Container) {
                $resolved = Join-Path $resolved '7z.exe'
            }
            if (Test-Path -LiteralPath $resolved -PathType Leaf) {
                $script:SevenZipExe = $resolved
                break
            }
        }
        Write-Warn "Path does not exist: $inputPath"
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Fail "PowerShell $($PSVersionTable.PSVersion) detected. Version 7 or newer is required."
}

if ($Help) {
    Show-Help
}

Write-Host ""
Write-Host "=== [ cosmickatamari's 7z Recompressor ]===" -ForegroundColor Blue
Write-Host "=== [ Version 2026.1 ] ===" -ForegroundColor Blue
Write-Host ""

$didPrompt = $false
if (-not $PSBoundParameters.ContainsKey('Include') -and -not $PSBoundParameters.ContainsKey('Skip')) {
    $Include = Read-YesNoDefaultNo "Would you like to process existing 7z files?"
    $didPrompt = $true
}

if (-not $PSBoundParameters.ContainsKey('Recursive')) {
    $Recursive = Read-YesNoDefaultNo "Would you like to scan all source subdirectories (recursive scan)?"
    $didPrompt = $true
}

if (-not $PSBoundParameters.ContainsKey('Replace')) {
    $Replace = Read-YesNoDefaultNo "Would you like to replace existing archive files with newer versions?"
    $didPrompt = $true
}

if (-not $Replace) {
    if (-not $PSBoundParameters.ContainsKey('Delete')) {
        $Delete = Read-YesNoDefaultNo "Do you want to delete the original archive after processing?"
        $didPrompt = $true
    }
} else {
    $Delete = $true
}

if (-not $PSBoundParameters.ContainsKey('FAT32') -and -not $PSBoundParameters.ContainsKey('CDRom')) {
    $splitChoice = Read-SplitChoice
    switch ($splitChoice) {
        'CDROM' { $CDRom = $true; $FAT32 = $false }
        'FAT32' { $FAT32 = $true; $CDRom = $false }
        Default { $CDRom = $false; $FAT32 = $false }
    }
    $didPrompt = $true
}

if (-not $PSBoundParameters.ContainsKey('Fast')) {
    $Fast = Read-YesNoDefaultNo "Do you want a potentially faster run with less accurate stats?"
    $didPrompt = $true
}

if ($didPrompt) {
    Write-Host ""
}

$includeOverridden = $false
if ($Skip -and $Include) {
    $Include = $false
    $includeOverridden = $true
}

$fat32Overridden = $false
if ($FAT32 -and $CDRom) {
    $FAT32 = $false
    $CDRom = $true
    $fat32Overridden = $true
}

Write-FlagStatus -Name "- Skipping existing 7z archives" -Enabled:$Skip
if ($includeOverridden) {
    Write-Host "- Including existing 7z archives" -NoNewline -ForegroundColor White
    Write-Host " was disabled (overridden)." -ForegroundColor Red
} else {
    Write-FlagStatus -Name "- Including existing 7z archives" -Enabled:$Include
}
Write-FlagStatus -Name "- Recursive scan" -Enabled:$Recursive
Write-FlagStatus -Name "- Replacing original (non 7z files)" -Enabled:$Replace
if ($Replace) {
    Write-Host "- Deleting the original source file" -NoNewline -ForegroundColor White
    Write-Host " is implied." -ForegroundColor Red
} else {
    Write-FlagStatus -Name "- Deleting the original source file" -Enabled:$Delete
}
if ($fat32Overridden) {
    Write-Host "- FAT32 split (4,000mb)" -NoNewline -ForegroundColor White
    Write-Host " was disabled (overridden)." -ForegroundColor Red
} else {
    Write-FlagStatus -Name "- FAT32 split (4,000mb)" -Enabled:$FAT32
}
Write-FlagStatus -Name "- CDROM split (650mb)" -Enabled:$CDRom
Write-FlagStatus -Name "- Less accurate run mode" -Enabled:$Fast
Write-Host ""

if ($Replace -and $Recursive) {
    Write-MessageWithFlags "You have passed the parameter -Replace along with -Recursive." -Color Yellow
    Write-Warn "This has the possibility to modify a large number of files and can take a long time."
    $prevColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = 'White'
    $answer = (Read-Host "Continue? (Y/N)").Trim()
    $Host.UI.RawUI.ForegroundColor = $prevColor
    if ($answer -notmatch '^(y|yes)$') {
        Write-Info "Operation cancelled."
        exit 0
    }
}

$sourceRoot = if ($Source) { Resolve-DirectoryPath -Path $Source } else { Read-DirectoryPath -Prompt "Enter the source folder containing compressed files" }
$tempRoot = if ($Temp) { Resolve-DirectoryPath -Path $Temp -CreateIfMissing } else { Read-DirectoryPath -Prompt "Enter the temp extraction folder" -CreateIfMissing }
$destRoot = if ($Replace) {
    $sourceRoot
} elseif ($Dest) {
    Resolve-DirectoryPath -Path $Dest -CreateIfMissing
} else {
    Read-DirectoryPath -Prompt "Enter the destination folder for 7z files" -CreateIfMissing
}
Write-Host ""

$reproArgs = @()
if ($Include) { $reproArgs += '-Include' }
if ($Skip) { $reproArgs += '-Skip' }
if ($Recursive) { $reproArgs += '-Recursive' }
if ($Replace) { $reproArgs += '-Replace' }
if ($Delete -and -not $Replace) { $reproArgs += '-Delete' }
if ($FAT32) { $reproArgs += '-FAT32' }
if ($CDRom) { $reproArgs += '-CDROM' }
if ($Fast) { $reproArgs += '-Fast' }

$reproArgs += @('-Source', "`"$sourceRoot`"")
$reproArgs += @('-Temp', "`"$tempRoot`"")
if (-not $Replace) {
    $reproArgs += @('-Dest', "`"$destRoot`"")
}

Write-Host "Quick Start Command:" -ForegroundColor DarkYellow
Write-Host (".\Recompress-To-7z.ps1 " + ($reproArgs -join ' ')) - ForegroundColor Cyan
Write-Host ""

$extensions = @(
    '.zip', '.7z', '.rar', '.tar', '.gz', '.bz2', '.xz', '.tgz', '.tbz', '.tbz2', '.txz'
)

$archives = if ($Recursive) {
    Get-ChildItem -LiteralPath $sourceRoot -File -Recurse
} else {
    Get-ChildItem -LiteralPath $sourceRoot -File
}
$archives = $archives | Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }
$archives = $archives | Sort-Object FullName

if (-not $archives) {
    Write-Warn "No compressed files were found."
    exit 0
}

$script:totalOriginalBytes = 0L
$script:totalNewBytes = 0L
$script:createdCount = 0
$script:totalExtractedFiles = 0
$script:renamedOutputs = @()
$overallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Invoke-ArchiveProcessing {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo[]]$ArchiveList)

    $lastDirectoryShown = $null
    foreach ($archive in $ArchiveList) {
        $script:totalOriginalBytes += $archive.Length
        $relativeDir = if ($Recursive) {
            Get-RelativeSubPath -RootPath $sourceRoot -FullPath $archive.DirectoryName
        } else {
            ''
        }

        if ($Recursive) {
            $currentDirDisplay = if ($relativeDir) { ".\$relativeDir" } else { '.' }
            if ($currentDirDisplay -ne $lastDirectoryShown) {
                Write-Host "Active directory: $currentDirDisplay" -ForegroundColor DarkCyan
                $lastDirectoryShown = $currentDirDisplay
            }
        }
        $extractDir = if ($relativeDir) {
            Join-Path (Join-Path $tempRoot $relativeDir) $archive.BaseName
        } else {
            Join-Path $tempRoot $archive.BaseName
        }

        Remove-ItemWithStatus -Path $extractDir -Label "Deleting Temp Files & Folders"
        New-Item -Path $extractDir -ItemType Directory -Force | Out-Null

        $filesFromArchive = Invoke-7zWithProgress -Label "Extracting" -FileName $archive.Name -Arguments @(
            'x', '-y', '-bb1', '-bso1', '-bse1', "-o$extractDir", $archive.FullName, '-bsp1'
        ) -CaptureFileCount

        if ($null -ne $filesFromArchive) {
            $script:totalExtractedFiles += $filesFromArchive
        } elseif (-not $Fast) {
            $script:totalExtractedFiles += (Get-ChildItem -LiteralPath $extractDir -Recurse -File | Measure-Object).Count
        }

        $destFolder = if ($Replace) {
            $archive.DirectoryName
        } elseif ($relativeDir) {
            Join-Path $destRoot $relativeDir
        } else {
            $destRoot
        }
        if (-not (Test-Path -LiteralPath $destFolder)) {
            New-Item -Path $destFolder -ItemType Directory -Force | Out-Null
        }

        $destFileName = $archive.BaseName + '.7z'
        $originalFileName = $destFileName
        $destFile = Join-Path $destFolder $destFileName
        if (-not $Replace -and (Test-Path -LiteralPath $destFile)) {
            $suffix = 1
            do {
                $prefix = ('cosmic-{0:D2}-' -f $suffix)
                $destFileName = $prefix + ($archive.BaseName + '.7z')
                $destFile = Join-Path $destFolder $destFileName
                $suffix++
            } while (Test-Path -LiteralPath $destFile)

            $script:renamedOutputs += @(
                @{
                    Original = $originalFileName
                    New = $destFileName
                }
            )
        }
        $splitArg = $null
        if ($Fat32) {
            $splitArg = '-v4000m'
        } elseif ($Cdrom) {
            $splitArg = '-v650m'
        }

        if ($Replace -and $archive.Extension.ToLowerInvariant() -eq '.7z') {
            Remove-ItemWithStatus -Path $archive.FullName -Label "Deleting Archive"
        }

        $compressArgs = @(
            'a', '-t7z', '-mx=9', '-m0=lzma2', '-mmt=on', '-y', '-bb1', '-bso1', '-bse1'
        )
        if ($splitArg) {
            $compressArgs += $splitArg
        }
        $compressArgs += @(
            $destFile, "$extractDir\*", '-bsp1'
        )

        Invoke-7zWithProgress -Label "Compressing" -FileName $destFileName -Arguments $compressArgs

        if (Test-Path -LiteralPath $destFile) {
            $script:totalNewBytes += (Get-Item -LiteralPath $destFile).Length
            $script:createdCount++
            if ($Replace -or $Delete) {
                if ($Replace -and $archive.Extension.ToLowerInvariant() -eq '.7z') {
                    # already deleted before recompressing to avoid removing the new file
                } elseif (Test-Path -LiteralPath $archive.FullName) {
                    Remove-ItemWithStatus -Path $archive.FullName -Label "Deleting Archive"
                }
            }
        }

        Remove-ItemWithStatus -Path $extractDir -Label "Deleting Temp Files"
        Write-Host ""
    }
}

$archivesToProcess = if ($Include) {
    $archives
} else {
    $archives | Where-Object { $_.Extension.ToLowerInvariant() -ne '.7z' }
}

if ($archivesToProcess) {
    Invoke-ArchiveProcessing -ArchiveList $archivesToProcess
}

$overallStopwatch.Stop()
$savedBytes = $script:totalOriginalBytes - $script:totalNewBytes
$savedPercent = if ($script:totalOriginalBytes -gt 0) {
    [Math]::Round(($savedBytes / $script:totalOriginalBytes) * 100, 2)
} else {
    0
}

if ($script:renamedOutputs.Count -gt 0) {
    Write-Warn "Output file name conflicts:"
    foreach ($item in $script:renamedOutputs) {
        Write-Host "  " -NoNewline -ForegroundColor Yellow
        Write-Host $item.Original -NoNewline -ForegroundColor DarkGray
        Write-Host " already existed, new version is " -NoNewline -ForegroundColor Yellow
        Write-Host $item.New -ForegroundColor Gray
    }
}

Write-Summary "===[ Completion Summary ]==="
Write-Summary "     Processing time:                $($overallStopwatch.Elapsed.ToString('hh\:mm\:ss'))"
Write-Summary "     Compressed file(s) created:     $script:createdCount"
Write-Summary "     Uncompressed files processed:   $($script:totalExtractedFiles.ToString('N0'))"
Write-Summary "     Overall original file size:     $(Format-SizePair $script:totalOriginalBytes)"
Write-Summary "     Overall new file size:          $(Format-SizePair $script:totalNewBytes)"
Write-Summary "     Overall space saved:            $(Format-SizePair $savedBytes) ($savedPercent`%)"
Write-Host ""