# Quick Script for folder and file cleanup based on file region.

# Declaring Global Variables
$RegionCounts = @{}
$startTime = Get-Date

# Load Windows Forms assembly
Add-Type -AssemblyName Microsoft.VisualBasic

# Prompt for folder path (manual input, allows UNC paths)
$SourceFolder = [Microsoft.VisualBasic.Interaction]::InputBox(
    "Enter the source folder (local or network) path (ex. \\tower.local\share):"
)

# Region variables (change as needed).
function Get-RegionFromFileName($name) {
    if ($name -match '(USA)') { return '01 - USA' }
    	elseif ($name -match '(World)') { return '01 - USA' }
	elseif ($name -match '(Japan)') { return '02 - Japan' }
    	elseif ($name -match '(Europe)') { return '03 - Europe' }
    	else { return '99 - Other' }
}

# Process files
Write-Host "Moving files into their correct region folders...`n" -ForegroundColor DarkCyan

Get-ChildItem -Path $SourceFolder -File | ForEach-Object {
    $region = Get-RegionFromFileName $_.Name
    $targetFolder = Join-Path -Path $SourceFolder -ChildPath $region

    # Make region folder, if needed
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder | Out-Null
    }

	Write-Host "Moving file '$($_.Name)' to folder '$region'" -ForegroundColor DarkGreen

    # If you get an error message on this part where the files are being moved, you should use PowerShell 7.5.1 or above.
    Move-Item -Path $_.FullName -Destination $targetFolder -Force

<# 
Checks to see if there are more than 256 files in a folder.
If there are more than 256 files, multiple child folders are created and the files will be moved based on the first word of the first file in the directory with the first word of the last file in the directory. This will repeat until all files for that region have been processed.

This is to help with Everdrive listing constraints of 256.
#> 

# Update region count.
    if (-not $RegionCounts.ContainsKey($region)) {
        $RegionCounts[$region] = 0
    }
    $RegionCounts[$region]++
}

# Process files into 256 chunks.
Write-Host "`nNow Moving files into their correct region folders with a maximum of 256 files..." -ForegroundColor DarkCyan

# Loop through each region folder
$RegionCounts.Keys | ForEach-Object {
    $region = $_
    $regionPath = Join-Path $SourceFolder $region

    # Get all files in the region folder, sorted alphabetically
    $files = Get-ChildItem -Path $regionPath -File | Sort-Object Name

    # If 256 or fewer, skip
    if ($files.Count -le 256) { return }

    # Chunk into groups of 256
    $chunks = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $files.Count; $i += 256) {
        $chunk = $files[$i..([math]::Min($i + 255, $files.Count - 1))]
        $chunks.Add($chunk) | Out-Null
    }

    # Process each chunk
    for ($j = 0; $j -lt $chunks.Count; $j++) {
        $chunk = $chunks[$j]
        $firstWord = ($chunk[0].BaseName -split '\s+')[0]
        $lastWord  = ($chunk[-1].BaseName -split '\s+')[0]

        $batchNum = "{0:D2}" -f ($j + 1)
        $folderName = "$batchNum - $firstWord - $lastWord" -replace '[<>:"/\\|?*]', ''

        $chunkFolder = Join-Path $regionPath $folderName
        if (-not (Test-Path $chunkFolder)) {
            New-Item -ItemType Directory -Path $chunkFolder | Out-Null
        }

        for ($i = 0; $i -lt $chunk.Count; $i++) {
            $file = $chunk[$i]
            $progressMsg = "Moving file $($i + 1) of $($chunk.Count) - ($($file.Name))"
            Write-Host -NoNewline ($progressMsg.PadRight([console]::WindowWidth) + "`r") -ForegroundColor DarkGreen
            Move-Item -Path $file.FullName -Destination $chunkFolder -Force
        }
    }
}

# Time calculations
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Final Move Summary
[console]::beep(250, 250)
Write-Host "`n`nMove Summary:" -ForegroundColor Cyan
foreach ($region in $RegionCounts.Keys) {
    $count = $RegionCounts[$region]
    Write-Host "$region`:` $count file(s)" -ForegroundColor DarkGray
}

Write-Host "`nProcess completed in $($duration.ToString())!" -ForegroundColor Yellow
