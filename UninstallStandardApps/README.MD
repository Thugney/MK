<#
Install command: powershell.exe -ExecutionPolicy Bypass -File uninstallStandardApps.ps1
Uninstall command: powershell.exe -ExecutionPolicy Bypass -File Uninstall.ps1
Rule type: File.
Path: %ProgramData%\Microsoft\RemoveW10Bloatware.
File or folder: RemoveW10Bloatware.ps1.tag.
Detection method: File or folder exists.

IntuneWinAppUtil.exe -c C:\Scripts\RemoveBloatware -s uinstallstandardapps.ps1 -o C:\Output
#>