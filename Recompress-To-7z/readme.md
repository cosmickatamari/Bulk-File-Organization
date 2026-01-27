# Recompress-To-7z
![7-Zip](https://img.shields.io/badge/7--Zip-required-blue) ![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue) ![Windows](https://img.shields.io/badge/Windows-11%2B-blue)

**Recompress-To-7z** is a PowerShell script that converts existing archives into `.7z` format using optimized compression settings to reduce storage size.

## Overview
This script is designed to recompress mixed archive formats (`rar`, `zip`, etc.) into high-compression `7z` files while keeping output organized and providing clear progress and summary information. It also supports optionally recompressing existing .7z archives using more aggressively tuned compression settings.

The script handles large batch operations, including nested directory structures, supports optional archive splitting for media or backup targets, and includes safety checks to help prevent destructive operations or accidental data loss.

## Purpose
- Reduce long-term storage requirements for archive collections.
- Normalize multiple archive formats into a single high-compression format.
- Automate bulk recompression with accurate progress and reporting.

## Features
- **Optimized `.7z` compression** (default high‑performance profile).
- **Legacy compression mode** (`-Old`) for low‑memory/CPU systems (not as many options are used).
- **Recursive scanning** with preserved folder structure.
- **Split archives** for FAT32 or CD‑ROM size targets.
- **Optional replace/delete workflows** for clean output management.
- **Progress output** for extract, compress, and delete operations.
- **Summary report** with time, file and size metrics.
- **Automatic prompt flow** when options are not supplied.
- **Rerun command** printed before processing for easy recovery.

## System Requirements
- PowerShell 7+
- 7‑Zip installed at: `C:\Program Files\7-Zip\7z.exe`
  - Or provide the path when prompted

## Recommended Hardware
- CPU with at least 8 cores
	- By default, 4 are used.
	- In `-Old`, 2 are used.
- 64gb RAM
	- In testing large files, 8-39gb RAM was used, depending on the file.
- Flash storage
	- In testing, the following were tested:
		- Western Digital m.2 - 1tb
		- Western Digital Red Plus - 3tb
		- Unraid XFS Array - 21x drives totaling 154tb

*Note:* This script was programmed and tested with Windows 11 25H2 and 7-Zip 22.01 (x64). On a network share accessed over a 1GbE connection.

## Mode Differences
|  | Default | -Old |
| -- | -- | -- |
| Compression Level | 9 - Ultra | 9 - Ultra |
| Compression Method | LZMA2 | LZMA2 |
| Dictionary Size | 1024mb | 64mb |
| Word Size | 273 | 64 |
| CPU Threads | 4 | 2 |
| Large Page Memory | Yes | No |
| Solid Compression | Yes | No |

## Results
The testing sample was a mixture of `7z` and `zip` files totaling 304.43gb.

|  | Default | -Old |
| -- | -- | -- |
| Processing Time | 24:32:59 | 20:31:42 |
| New Compressed Size | 253.54gb | 286.64gb |
| Space Saved | 50.90gb (16.72%) | 17.79gb (5.52%) |

## Usage
Provides on screen help:
```powershell
.\Recompress-To-7z.ps1 -Help
```

Will generate all interactive prompts:
```powershell
.\Recompress-To-7z.ps1
```

Will use the ignore file to ignore subdirectories within the `source` folder:
```powershell
.\Recompress-To-7z.ps1 -Ignore
```

Providing all folder infomation:
```powershell
.\Recompress-To-7z.ps1 -Source D:\source -Temp D:\temp -Dest D:\output
```

Include existing `.7z` files to be recompressed:
```powershell
.\Recompress-To-7z.ps1 -Include -Source D:\source -Temp D:\temp -Dest D:\output
```

Replace originals in place (if passing `destination`, would be ignored):
```powershell
.\Recompress-To-7z.ps1 -Replace -Source D:\source -Temp D:\temp
```

Recursive scan with max CD‑ROM file size split:
```powershell
.\Recompress-To-7z.ps1 -Recursive -CDROM -Source D:\source -Temp D:\temp -Dest D:\output
```

Legacy compression (lower memory/CPU usage):
```powershell
.\Recompress-To-7z.ps1 -Old -Source D:\source -Temp D:\temp -Dest D:\output
```

** *Note:* ** You will be prompted for any missing parameters, unless they are mutually exclusive with a provided parameter.

## Key Parameters
### Flags
- `-Include` - process existing `.7z` files.
- `-Skip` - skip existing `.7z` files (default).
- `-Recursive` - include subdirectories during the scan.
- `-Replace` - write new `.7z` into source folder and delete original archive.
- `-Delete` - delete original archive after recompression.
- `-FAT32` - split output into 4,000mb volumes.
- `-CDROM` - split output into 650mb volumes.
- `-Fast` - skip fallback file count (faster, less accurate stats).
- `-Ignore` - Use `recomp-ignore.txt` in the source folder for folders to exclude.
- `-Old` - use legacy compression settings.

### Paths
- `-Source <path>`
- `-Temp <path>`
- `-Dest <path>` (ignored when `-Replace` is used)

## Notes
- If both `-Include` and `-Skip` are used, **`-Skip` has priority** and `-Include` is ignored.
- If both `-FAT32` and `-CDROM` are used, **`-CDROM` has priority** and `-FAT32` is ignored.
- `-Replace` implies delete of the original archive.
- Fast skips fallback file counts when 7-Zip doesn't report totals.
- Old uses less optimized compression settings (lower memory/CPU) to decrease chances of memory errors.
- Ignore checks the paths in `recomp-ignore.txt` (one path per line) against the source folder.
- Temp extraction files and folders are cleaned up automatically.

## What You’ll See
Per file:
- Extracting progress.
- Compressing progress.
- Deleting temp files (and archive if enabled).

Summary:
- Total runtime.
- Count of created `.7z` files.
- Total extracted file count (if available).
- Original size vs. new size.
- Space saved and percentage.

## FAQ
**Q: Why do some `.7z` files get larger after recompressing?**

**A:** The source archive may already be optimal (solid mode, dictionary size, filters). Recompressing with different settings can increase size, especially for already compressed data (images/audio/video).

**Q: When should I use `-Old`?**

**A:** Use it on low memory or lower core systems. It uses a lighter compression profile that is slower to compress than zip but consumes less RAM/CPU than the optimized default. It will still generate better results than using `ZIP` or `RAR`.

**Q: How do I setup the ignore file?**

**A:** Each line should be a seperate directory.

**Q: How do I include existing `.7z` files?**

**A:** Pass `-Include`. Without it, `.7z` files are skipped by default.

**Q: Why did the script ask to re‑enter the destination folder?**

**A:** If `-Replace` and `-Delete` are both off, source and destination cannot be the same to avoid overwriting.

**Q: I’m using network paths/UNC shares. Is that supported?**

**A:** Yes. The script resolves provider paths to filesystem paths before calling 7‑Zip, which avoids UNC prefix issues.

**Q: How do I re‑run the same job after an error?**

**A:** The script prints a “Re‑run command” line before processing begins. Copy/paste that to retry.

**Q: Will it preserve folder structure when recursive?**
**A:** Yes. With `-Recursive`, the destination mirrors the source subfolder structure. Difference being that non-7z archives will be replaced with 7z archives. None archive files are ignored.

## Project
Part of: https://github.com/cosmickatamari/cosmic-file-suite
