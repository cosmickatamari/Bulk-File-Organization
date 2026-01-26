# Make Junk Files

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue) ![Windows](https://img.shields.io/badge/Windows-11%2B-blue)

**Make Junk Files** is a PowerShell script that generates randomized `.txt` files for bulk file testing, each containing a timestamp to avoid zero-byte issues.

## Overview

This script creates a user defined number of junk files in a target directory using random name combinations. Names are loaded from `junk-names.txt` in the script folder and can be comma-delimited or one-per-line. If the list is missing or only has one entry, random 8-character strings are used to fill in.

## Purpose

- Create large batches of files for organizational or performance testing.
- Avoid zero-byte files by writing a timestamp payload.
- Provide a quick, repeatable way to generate junk files in any folder.

## Features

- **Interactive prompts** when `-Target` or `-FileNum` are missing.
- **External name list** in `junk-names.txt`.
- **Fallback naming** with random 8-character strings if needed.
- **Auto-create target directory** when missing.
- **Safety confirmation** when generating more than 1000 files.

## System Requirements

- PowerShell 7+
- Windows 11

## Usage

Provides on-screen help:
```powershell
.\make-junk-files.ps1 -Help
```

Will generate all interactive prompts:
```powershell
.\make-junk-files.ps1
```

Provide target and file count:
```powershell
.\make-junk-files.ps1 -Target D:\Temp -FileNum 500
```

## Key Parameters

### Flags

- `-Help` - show the help screen and exit.

### Parameters

- `-Target <path>`
- `-FileNum <int>`

## Name List Format

`junk-names.txt` supports:

- comma-delimited values
- one entry per line

Both formats can be mixed:

```
Cloud, Tifa, Barret
Aeris
Cid, Yuffie
```

## Notes

- If `junk-names.txt` is missing, random 8-character names are used.
- If only one name is provided, the second name is random.
- Each file includes a timestamp to avoid zero-byte issues.
- Large batches of zero-byte files can cause Explorer to freeze or crash.

## What You’ll See

- A header with script name and version.
- Prompts for missing parameters.
- A confirmation prompt when `-FileNum` is over 1000.
- A completion message with the total file count and destination.

## FAQ

**Q: Where does the script look for `junk-names.txt`?**

**A:** In the same folder as `make-junk-files.ps1`.

**Q: What happens if `junk-names.txt` is missing?**

**A:** The script uses random 8-character alphanumeric names.

**Q: What if the name list only has one entry?**

**A:** The first token uses the single name, the second is random.

## Project

Part of: https://github.com/cosmickatamari/cosmic-file-suite
