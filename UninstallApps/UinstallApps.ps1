# Detection Script for Intune Proactive Remediation (Multi-App)
# Detects if specified apps are installed, including per-user checks
# Exit: 0 = Compliant (none found), 1 = Non-Compliant (any found)

$Apps = @(
    @{
        DisplayName = "Azure Information Protection"
        Publisher = "Microsoft Corporation"
        ProductCode = "{86B70A45-00A6-4CBD-97A8-464A1254D179}"
        UninstallString = ""
        UsePartialMatch = $true
    },
    @{
        DisplayName = "Zoom"
        Publisher = "Zoom Video Communications"
        ProductCode = ""
        UninstallString = ""
        UsePartialMatch = $true
    },
    @{
        DisplayName = "VLC media player"
        Publisher = "VideoLAN"
        ProductCode = ""
        UninstallString = ""
        UsePartialMatch = $true
    }
)

$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogPath\AppDetection_$(Get-Date -Format 'yyyyMMdd').log"

function Write-LogEntry {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
    Add-Content -Path $LogFile -Value $LogEntry -Force
    switch ($Level) {
        "INFO" { Write-Host $LogEntry -ForegroundColor Green }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
    }
}

function Get-UserProfiles {
    Get-ChildItem -Path "C:\Users" -Directory | Where-Object { ${_.Name} -notin @("Public", "Default") } | Select-Object -ExpandProperty FullName
}

function Test-AppViaRegistry {
    param(
        [hashtable]$AppConfig,
        [string]$UserProfile = $null
    )
    $DisplayName = ${AppConfig}.DisplayName
    $Publisher = ${AppConfig}.Publisher
    $ProductCode = ${AppConfig}.ProductCode
    $UninstallString = ${AppConfig}.UninstallString
    $PartialMatch = ${AppConfig}.UsePartialMatch

    $Context = if ($UserProfile) { "User: ${UserProfile}" } else { "System" }
    Write-LogEntry "Checking '${DisplayName}' via Registry (${Context})..."

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    if ($UserProfile) {
        $NTUserDat = "${UserProfile}\NTUSER.DAT"
        if (Test-Path $NTUserDat) {
            $username = Split-Path ${UserProfile} -Leaf
            $isLoggedIn = (Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue | Where-Object { ${_.UserName} -like "*\${username}" }) -or
                          (query user /server:${env:COMPUTERNAME} | Select-String ${username})
            if ($isLoggedIn) {
                Write-LogEntry "Skipping hive load for active user: ${username} (profile in use)" "WARN"
                try {
                    $sid = (New-Object System.Security.Principal.NTAccount(${username})).Translate([System.Security.Principal.SecurityIdentifier]).Value
                    $RegistryPaths += "HKU:\${sid}\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                } catch {
                    Write-LogEntry "Failed to get SID for active user ${username}: $(${_.Exception.Message})" "ERROR"
                    return $null
                }
            } else {
                try {
                    reg load HKU\TempHive $NTUserDat | Out-Null
                    $RegistryPaths += "HKU:\TempHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                } catch {
                    Write-LogEntry "Failed to load hive for ${UserProfile}: $(${_.Exception.Message})" "ERROR"
                    return $null
                }
            }
        }
    }

    foreach ($Path in $RegistryPaths) {
        try {
            $InstalledApps = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | Where-Object { ${_.DisplayName} }
            foreach ($App in $InstalledApps) {
                $Match = $false
                if (-not [string]::IsNullOrEmpty(${DisplayName})) {
                    $Match = if (${PartialMatch}) { ${App}.DisplayName -like "*${DisplayName}*" } else { ${App}.DisplayName -eq ${DisplayName} }
                }
                if ($Match) {
                    if (-not [string]::IsNullOrEmpty(${Publisher}) -and ${App}.Publisher -notlike "*${Publisher}*") { $Match = $false }
                    if (-not [string]::IsNullOrEmpty(${ProductCode}) -and ${App}.PSChildName -ne ${ProductCode}) { $Match = $false }
                    if (-not [string]::IsNullOrEmpty(${UninstallString}) -and ${App}.UninstallString -notlike "*${UninstallString}*") { $Match = $false }
                    if ($Match) {
                        Write-LogEntry "Found: ${App}.DisplayName (Version: ${App}.DisplayVersion) in ${Context}" "INFO"
                        if ($UserProfile -and -not $isLoggedIn) { reg unload HKU\TempHive | Out-Null 2>$null }
                        return $App
                    }
                }
            }
        } catch {
            Write-LogEntry "Error checking registry path ${Path}: $(${_.Exception.Message})" "ERROR"
        }
    }
    if ($UserProfile -and -not $isLoggedIn) { reg unload HKU\TempHive | Out-Null 2>$null }
    return $null
}

function Test-AppViaWMI {
    param(
        [hashtable]$AppConfig
    )
    $DisplayName = ${AppConfig}.DisplayName
    $ProductCode = ${AppConfig}.ProductCode
    $PartialMatch = ${AppConfig}.UsePartialMatch

    Write-LogEntry "Checking '${DisplayName}' via WMI..."

    try {
        if (-not [string]::IsNullOrEmpty(${ProductCode})) {
            $WMIProduct = Get-WmiObject -Class Win32_Product -Filter "IdentifyingNumber='${ProductCode}'" -ErrorAction SilentlyContinue
            if ($WMIProduct) {
                Write-LogEntry "Found via WMI (Product Code): ${WMIProduct}.Name" "INFO"
                return $WMIProduct
            }
        }
        if (-not [string]::IsNullOrEmpty(${DisplayName})) {
            $Filter = if (${PartialMatch}) { "Name LIKE '%${DisplayName}%'" } else { "Name = '${DisplayName}'" }
            $WMIProduct = Get-WmiObject -Class Win32_Product -Filter $Filter -ErrorAction SilentlyContinue
            if ($WMIProduct) {
                Write-LogEntry "Found via WMI (Name): ${WMIProduct}.Name" "INFO"
                return $WMIProduct
            }
        }
    } catch {
        Write-LogEntry "Error during WMI query: $(${_.Exception.Message})" "WARN"
    }
    return $null
}

function Test-SingleAppDetection {
    param(
        [hashtable]$AppConfig
    )
    $DetectedApp = Test-AppViaRegistry -AppConfig ${AppConfig}
    if ($DetectedApp) { return $true, $DetectedApp }

    $userProfiles = Get-UserProfiles
    foreach ($userProfile in $userProfiles) {
        $DetectedApp = Test-AppViaRegistry -AppConfig ${AppConfig} -UserProfile ${userProfile}
        if ($DetectedApp) { return $true, $DetectedApp }
    }

    $DetectedApp = Test-AppViaWMI -AppConfig ${AppConfig}
    if ($DetectedApp) { return $true, $DetectedApp }

    return $false, $null
}

Write-LogEntry "=== Starting Multi-App Detection ===" "INFO"
Write-LogEntry "Total Apps to Check: ${Apps}.Count" "INFO"

$AnyAppFound = $false
$FoundApps = @()

try {
    foreach ($AppConfig in $Apps) {
        Write-LogEntry "--- Checking App: ${AppConfig}.DisplayName ---" "INFO"
        Write-LogEntry "Publisher: ${AppConfig}.Publisher" "INFO"
        Write-LogEntry "Product Code: ${AppConfig}.ProductCode" "INFO"
        Write-LogEntry "Partial Match: ${AppConfig}.UsePartialMatch" "INFO"

        $Found, $DetectedApp = Test-SingleAppDetection -AppConfig ${AppConfig}

        if ($Found) {
            $AnyAppFound = $true
            $FoundApps += [PSCustomObject]@{ Config = ${AppConfig}; Detected = ${DetectedApp} }
            Write-LogEntry "RESULT: FOUND" "WARN"
        } else {
            Write-LogEntry "RESULT: NOT FOUND" "INFO"
        }
    }

    if ($AnyAppFound) {
        Write-LogEntry "DETECTION RESULT: ${FoundApps}.Count app(s) found - INSTALLED (Non-Compliant)" "WARN"
        foreach ($FoundApp in $FoundApps) {
            Write-LogEntry "Found App Details: ${FoundApp}.Config.DisplayName via ${FoundApp}.Detected.DisplayName" "INFO"
        }
        Write-LogEntry "=== Detection Complete - Non-Compliant ===" "INFO"
        exit 1
    } else {
        Write-LogEntry "DETECTION RESULT: No apps found - NOT INSTALLED (Compliant)" "INFO"
        Write-LogEntry "=== Detection Complete - Compliant ===" "INFO"
        exit 0
    }
} catch {
    Write-LogEntry "Critical error during detection: $(${_.Exception.Message})" "ERROR"
    exit 0
}