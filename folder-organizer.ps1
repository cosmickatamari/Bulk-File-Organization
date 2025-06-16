# Quick Script for folder cleanup after cleaning up ROMS.

# Declaring Global Variables
$RegionCounts = @{}
$startTime = Get-Date

# Load Windows Forms assembly
Add-Type -AssemblyName Microsoft.VisualBasic

# Prompt for folder path (manual input, allows UNC paths)
$SourceFolder = [Microsoft.VisualBasic.Interaction]::InputBox(
    "Enter the source folder path (you can also paste a network path - \\tower.local\share):"
)

# Simulate region detection
function Get-RegionFromFileName($name) {
    if ($name -match 'USA') { return '01 - USA' }
    elseif ($name -match 'World') { return '01 - USA' }
	elseif ($name -match 'Japan') { return '02 - Japan' }
    elseif ($name -match 'Europe') { return '03 - Europe' }
    else { return 'OTHER' }
}

# Process files
Write-Host "Moving files into their correct region folders..." -ForegroundColor DarkCyan

Get-ChildItem -Path $SourceFolder -File | ForEach-Object {
    $region = Get-RegionFromFileName $_.Name
    $targetFolder = Join-Path -Path $SourceFolder -ChildPath $region

    # Make region folder, if needed
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder | Out-Null
    }

	Write-Host "Moving file '$($_.Name)' to folder '$region'" -ForegroundColor DarkCyan

    # If you get an error message on this part where the files are being moved, you should use PowerShell 7.5.1 or above.
    Move-Item -Path $_.FullName -Destination $targetFolder -Force

    # Update region count
    if (-not $RegionCounts.ContainsKey($region)) {
        $RegionCounts[$region] = 0
    }
    $RegionCounts[$region]++
}

<# 
Checks to see if there are 256 files in the folder. 
If there is, it will begin moving them into child directories back on the first name of the title for the first and last file in that folder. This is to help with Everdrive listing constraints of 256.
#> 

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

        $batchNum = "{0:D2}" -f ($j + 1)  # 01, 02, etc.
        $folderName = "$batchNum - $firstWord - $lastWord" -replace '[<>:"/\\|?*]', ''

        $chunkFolder = Join-Path $regionPath $folderName
        if (-not (Test-Path $chunkFolder)) {
            New-Item -ItemType Directory -Path $chunkFolder | Out-Null
        }

        for ($i = 0; $i -lt $chunk.Count; $i++) {
            $file = $chunk[$i]
            $progressMsg = "Moving file $($i + 1) of $($chunk.Count) ($($file.Name))"
            Write-Host -NoNewline ("`r" + $progressMsg.PadRight([console]::WindowWidth)) -ForegroundColor Cyan

            Move-Item -Path $file.FullName -Destination $chunkFolder -Force
        }

        # Clear line after chunk
		# Write-Host ("`r" + (" " * [console]::WindowWidth) + "`r")
    }
}

# Done — timer + report
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Final Move Summary
Write-Host "`n`nMove Summary:" -ForegroundColor Cyan
foreach ($region in $RegionCounts.Keys) {
    $count = $RegionCounts[$region]
    Write-Host "$region`:` $count file(s)" -ForegroundColor DarkGray
}
Write-Host "`n`nProcess completed in $($duration.ToString())!" -ForegroundColor DarkRed