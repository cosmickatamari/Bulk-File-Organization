# Bulk File Organization

This set of scripts aims to easily manage a large amount of files. I've decided that after a long time of needing to perform the same repeditive tasks isn't fun, so I scripted these things out. In that, I figured someone else out there might benefit from it as well. Everything on here was tested using PowerShell 7.5.1 in administrator mode on Windows 11 24h2.

The majority of the scripts on here are easy to edit for folder locations.

Scripts in this repository are:
> Make Junk Files - This was simply designed to make junk files to test out other scripts before mass deploying them on real data. Think of this as making a test environment on garbage files.

> Region Organizer - When you have files based on certain regions, use this to organize them from an unorganized parent folder to child folders based on the region. On line 16, function Get-RegionFromFileName can be edited based on your region needs. Currently, it's set for USA and World in USA. Followed by Japan and Europe in their respective folders.
