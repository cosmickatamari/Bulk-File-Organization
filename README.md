# Bulk File Organization

![Bulk File Organization Header Image](https://i.imgur.com/OTGhGZI.png)

This repository of scripts aims to easily manage a large amount of files. I've decided that after a long time of needing to perform the same repeditive tasks isn't fun, so I scripted these things out. With that, I figured someone else out there might benefit from it as well. Everything on here was tested using PowerShell 7.5.1 in administrator mode on Windows 11 24h2. 

> [!IMPORTANT]
> As with most PowerShell scripts, they aren't signed. You will need to execute the following command prior to running any script:
>
> `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

The majority of the scripts on here are easy to edit folder locations but I'm working on making them popup windows, allowing the directory is be selected on the fly.

Scripts in this repository are:
+ Make Junk Files - This was simply designed to make junk files to test out other scripts before mass deploying on real data. Think of this as making a test environment with garbage files.
+ Region Organizer - When you have files based on certain regions, use this to organize them from an unorganized parent folder to child folders based on the region. On line 16, $${\color{red}function Get-RegionFromFileName}$$ can be edited based on your region needs.
  + USA and World are filtered into the defined folder for USA.
  + Japan into the defined folder for Japan.
  + Europe into the defined folder for Europe.
  + A catch all folder for what is remaining goes into a folder called "Other".
