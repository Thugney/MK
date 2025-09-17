# ===================================================================
# Application Detection Script for Intune Proactive Remediation
# Purpose: Detect if specified application is installed
# Exit Codes: 0 = Not Found (Compliant), 1 = Found (Non-Compliant)
# ===================================================================

# CONFIGURATION SECTION - CUSTOMIZE THESE VARIABLES
# ===================================================================
$AppDisplayName = "Zoom"           # Application display name (partial match supported)
$AppPublisher = ""                        # Optional: Publisher name for additional validation
$AppProductCode = "{86B70A45-00A6-4CBD-97A8-464A1254D179}"#Get-WmiObject Win32_Product |Format-Table Name, IdentifyingNumber
$AppUninstallString = ""                  # Optional: Specific uninstall string to look for
$UsePartialMatch = $true                  # Set to $false for exact name matching only

# LOGGING CONFIGURATION
$LogPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogPath\AppDetection_$(Get-Date -Format 'yyyyMMdd').log"

# ===================================================================
# FUNCTIONS
# ===================================================================

function Write-LogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$TimeStamp] [$Level] $Message"
    
    # Create log directory if it doesn't exist
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogEntry -Force
    
    # Write to host for immediate feedback
    switch ($Level) {
        "INFO" { Write-Host $LogEntry -ForegroundColor Green }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
    }
}

function Test-AppViaRegistry {
    param(
        [string]$DisplayName,
        [string]$Publisher,
        [string]$ProductCode,
        [string]$UninstallString,
        [bool]$PartialMatch
    )
    
    Write-LogEntry "Starting registry-based detection..."
    
    # Registry paths to check
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($Path in $RegistryPaths) {
        try {
            $InstalledApps = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName }
            
            foreach ($App in $InstalledApps) {
                $Match = $false
                
                # Check by Display Name
                if (-not [string]::IsNullOrEmpty($DisplayName)) {
                    if ($PartialMatch) {
                        $Match = $App.DisplayName -like "*$DisplayName*"
                    } else {
                        $Match = $App.DisplayName -eq $DisplayName
                    }
                }
                
                # Additional validation checks
                if ($Match) {
                    # Validate Publisher if specified
                    if (-not [string]::IsNullOrEmpty($Publisher) -and $App.Publisher -notlike "*$Publisher*") {
                        $Match = $false
                    }
                    
                    # Validate Product Code if specified
                    if (-not [string]::IsNullOrEmpty($ProductCode) -and $App.PSChildName -ne $ProductCode) {
                        $Match = $false
                    }
                    
                    # Validate Uninstall String if specified
                    if (-not [string]::IsNullOrEmpty($UninstallString) -and $App.UninstallString -notlike "*$UninstallString*") {
                        $Match = $false
                    }
                    
                    if ($Match) {
                        Write-LogEntry "Application found via Registry: $($App.DisplayName) (Version: $($App.DisplayVersion))" "INFO"
                        return $App
                    }
                }
            }
        }
        catch {
            Write-LogEntry "Error checking registry path $Path`: $($_.Exception.Message)" "ERROR"
        }
    }
    
    return $null
}

function Test-AppViaWMI {
    param(
        [string]$DisplayName,
        [string]$ProductCode,
        [bool]$PartialMatch
    )
    
    Write-LogEntry "Starting WMI-based detection..."
    
    try {
        # Query Win32_Product (MSI products only)
        if (-not [string]::IsNullOrEmpty($ProductCode)) {
            $WMIProduct = Get-WmiObject -Class Win32_Product -Filter "IdentifyingNumber='$ProductCode'" -ErrorAction SilentlyContinue
            if ($WMIProduct) {
                Write-LogEntry "Application found via WMI (Product Code): $($WMIProduct.Name)" "INFO"
                return $WMIProduct
            }
        }
        
        # Query by name
        if (-not [string]::IsNullOrEmpty($DisplayName)) {
            $Filter = if ($PartialMatch) {
                "Name LIKE '%$DisplayName%'"
            } else {
                "Name = '$DisplayName'"
            }
            
            $WMIProduct = Get-WmiObject -Class Win32_Product -Filter $Filter -ErrorAction SilentlyContinue
            if ($WMIProduct) {
                Write-LogEntry "Application found via WMI (Name): $($WMIProduct.Name)" "INFO"
                return $WMIProduct
            }
        }
    }
    catch {
        Write-LogEntry "Error during WMI query: $($_.Exception.Message)" "WARN"
    }
    
    return $null
}

function Test-AppViaPrograms {
    param(
        [string]$DisplayName,
        [bool]$PartialMatch
    )
    
    Write-LogEntry "Starting Programs list detection..."
    
    try {
        $Programs = Get-ItemProperty -Path @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        ) -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, PSChildName
        
        foreach ($Program in $Programs) {
            $Match = $false
            
            if ($PartialMatch) {
                $Match = $Program.DisplayName -like "*$DisplayName*"
            } else {
                $Match = $Program.DisplayName -eq $DisplayName
            }
            
            if ($Match) {
                Write-LogEntry "Application found via Programs list: $($Program.DisplayName)" "INFO"
                return $Program
            }
        }
    }
    catch {
        Write-LogEntry "Error checking Programs list: $($_.Exception.Message)" "ERROR"
    }
    
    return $null
}

# ===================================================================
# MAIN EXECUTION
# ===================================================================

Write-LogEntry "=== Starting Application Detection ===" "INFO"
Write-LogEntry "Target Application: $AppDisplayName" "INFO"
Write-LogEntry "Publisher Filter: $AppPublisher" "INFO"
Write-LogEntry "Product Code: $AppProductCode" "INFO"
Write-LogEntry "Partial Match: $UsePartialMatch" "INFO"

$AppFound = $false
$DetectedApp = $null

try {
    # Method 1: Registry Detection (Fastest and most reliable)
    $DetectedApp = Test-AppViaRegistry -DisplayName $AppDisplayName -Publisher $AppPublisher -ProductCode $AppProductCode -UninstallString $AppUninstallString -PartialMatch $UsePartialMatch
    if ($DetectedApp) {
        $AppFound = $true
        Write-LogEntry "Application detected via Registry method" "INFO"
    }
    
    # Method 2: WMI Detection (If registry didn't find it)
    if (-not $AppFound) {
        $DetectedApp = Test-AppViaWMI -DisplayName $AppDisplayName -ProductCode $AppProductCode -PartialMatch $UsePartialMatch
        if ($DetectedApp) {
            $AppFound = $true
            Write-LogEntry "Application detected via WMI method" "INFO"
        }
    }
    
    # Method 3: Programs List (Fallback method)
    if (-not $AppFound) {
        $DetectedApp = Test-AppViaPrograms -DisplayName $AppDisplayName -PartialMatch $UsePartialMatch
        if ($DetectedApp) {
            $AppFound = $true
            Write-LogEntry "Application detected via Programs list method" "INFO"
        }
    }
    
    # Final Result
    if ($AppFound) {
        Write-LogEntry "DETECTION RESULT: Application '$AppDisplayName' is INSTALLED" "WARN"
        Write-LogEntry "=== Detection Complete - Non-Compliant ===" "INFO"
        exit 1  # Non-compliant - App found, remediation needed
    } else {
        Write-LogEntry "DETECTION RESULT: Application '$AppDisplayName' is NOT INSTALLED" "INFO"
        Write-LogEntry "=== Detection Complete - Compliant ===" "INFO"
        exit 0  # Compliant - App not found
    }
}
catch {
    Write-LogEntry "Critical error during detection: $($_.Exception.Message)" "ERROR"
    Write-LogEntry "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 0  # Exit as compliant to avoid remediation on error
}