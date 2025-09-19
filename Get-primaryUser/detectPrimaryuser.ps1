function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    # Enhanced logging: Append to file for persistence
    $logFile = "$env:TEMP\PrimaryUserLogonDetection_$(Get-Date -Format 'yyyyMMdd').log"
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

try {
    Write-Log "Starting Primary User Login Restriction Detection Script"

    # Get the primary user (same as remediation)
    $primaryUserUPN = $null
    $enrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    $enrollmentKeys = Get-ChildItem -Path $enrollmentPath -ErrorAction SilentlyContinue

    foreach ($key in $enrollmentKeys) {
        $keyPath = $key.PSPath
        try {
            $upn = Get-ItemProperty -Path $keyPath -Name "UPN" -ErrorAction SilentlyContinue
            if ($upn.UPN) {
                $primaryUserUPN = $upn.UPN
                Write-Log "Found primary user from Intune enrollment: $primaryUserUPN"
                break
            }
        } catch {
            Write-Log "Error reading UPN from registry key $keyPath: $($_.Exception.Message)" "WARNING"
            continue
        }
    }

    # Fallback: Get from Azure AD join info
    if (-not $primaryUserUPN) {
        try {
            $dsregStatus = dsregcmd /status
            $userEmailLine = $dsregStatus | Where-Object { $_ -match "UserEmail\s*:" }
            if ($userEmailLine) {
                $primaryUserUPN = ($userEmailLine -split ":")[1].Trim()
                Write-Log "Found primary user from dsregcmd: $primaryUserUPN"
            }
        } catch {
            Write-Log "Could not determine primary user from dsregcmd: $($_.Exception.Message)" "ERROR"
        }
    }

    if (-not $primaryUserUPN) {
        Write-Log "Could not determine primary user" "ERROR"
        exit 1
    }

    # Autopilot Enrollment Check (same as remediation)
    Write-Log "Validating Autopilot enrollment..."
    $autopilotCache = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache" -Name "PolicyJsonCache" -ErrorAction SilentlyContinue
    $approvedGUIDs = @("YourApprovedGUID1", "YourApprovedGUID2")  # Replace with your actual approved ZtdCorrelationId values
    if ($autopilotCache) {
        try {
            $policyJson = $autopilotCache.PolicyJsonCache | ConvertFrom-Json
            $ztdCorrelationId = $policyJson.ZtdCorrelationId
            if ($ztdCorrelationId -notin $approvedGUIDs) {
                Write-Log "Device not enrolled via approved Autopilot profile (ID: $ztdCorrelationId)" "ERROR"
                exit 1
            }
            Write-Log "Autopilot enrollment validated: $ztdCorrelationId"
        } catch {
            Write-Log "Error parsing Autopilot policy: $($_.Exception.Message)" "WARNING"
        }
    } else {
        Write-Log "No Autopilot cache found - proceeding with caution" "WARNING"
    }

    # Get user SID (same robust methods as remediation)
    Write-Log "Looking up user SID for: $primaryUserUPN"
    $userSID = $null
    $usernamePrefix = $primaryUserUPN.Split('@')[0].Replace('.', '')

    # Method 1: Match local profile
    $profileList = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction SilentlyContinue | Where-Object { $_.ProfileImagePath -like "*Users*" }
    foreach ($profile in $profileList) {
        $profilePath = $profile.ProfileImagePath
        $username = Split-Path $profilePath -Leaf
        if ($primaryUserUPN -like "*$username*" -or $username -like "*$usernamePrefix*" -or $username -eq $primaryUserUPN.Split('@')[0]) {
            $userSID = $profile.PSChildName
            Write-Log "Found matching user SID: $userSID for profile: $profilePath"
            break
        }
    }

    # Method 2: Get SID from dsregcmd /status
    if (-not $userSID) {
        try {
            $dsregStatus = dsregcmd /status
            $userSidLine = $dsregStatus | Where-Object { $_ -match "UserSid\s*:" }
            if ($userSidLine) {
                $userSID = ($userSidLine -split ":")[1].Trim()
                Write-Log "Found user SID from dsregcmd: $userSID"
            } else {
                Write-Log "No UserSid found in dsregcmd output" "WARNING"
            }
        } catch {
            Write-Log "Error retrieving SID from dsregcmd: $($_.Exception.Message)" "ERROR"
        }
    }

    # Method 3: Try to resolve SID using .NET SecurityPrincipal
    if (-not $userSID) {
        try {
            $username = $primaryUserUPN.Split('@')[0]
            $ntAccount = New-Object System.Security.Principal.NTAccount($username)
            $sid = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
            $userSID = $sid.Value
            Write-Log "Resolved SID using NTAccount: $userSID for username: $username"
        } catch {
            Write-Log "Could not resolve SID using NTAccount for $username: $($_.Exception.Message)" "WARNING"
        }
    }

    # Additional SID Fallback - IdentityStore Cache
    if (-not $userSID) {
        Write-Log "Attempting SID lookup via IdentityStore Cache..."
        $identityStorePath = "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache"
        $aadProviderGUID = "{C29E6DB4-E553-4969-864A-F36D7EB889E9}"
        $upnKey = Get-ChildItem "$identityStorePath\$aadProviderGUID\Identity" -ErrorAction SilentlyContinue | Where-Object { 
            try {
                (Get-ItemProperty $_.PSPath -Name "UserName" -ErrorAction SilentlyContinue).UserName -eq $primaryUserUPN
            } catch { $false }
        }
        if ($upnKey) {
            $userSID = (Get-ItemProperty $upnKey.PSPath -Name "Sid" -ErrorAction SilentlyContinue).Sid
            if ($userSID) {
                Write-Log "Found SID from IdentityStore: $userSID"
            }
        } else {
            Write-Log "No matching UPN found in IdentityStore" "WARNING"
        }
    }

    # Validate SID
    if (-not $userSID -or $userSID -notmatch "^S-1-(5|12)-") {
        Write-Log "Could not determine valid user SID for primary user: $primaryUserUPN" "ERROR"
        exit 1
    }

    Write-Log "Primary User: $primaryUserUPN"
    Write-Log "Primary User SID: $userSID"

    # Check current security policy
    $tempFile = "$env:TEMP\secpol_check.cfg"
    Write-Log "Exporting security policy for check..."
    secedit /export /cfg $tempFile /quiet
    
    if (Test-Path $tempFile) {
        $policyContent = Get-Content $tempFile
        $logonRightLine = $policyContent | Where-Object { $_ -match "^SeInteractiveLogonRight\s*=" }
        
        if ($logonRightLine) {
            # Check if policy is properly restricted (includes primary SID + admins, no broad groups like Users or Everyone)
            if ($logonRightLine -match "\*$userSID," -and $logonRightLine -match "S-1-5-32-544" -and 
                $logonRightLine -notmatch "S-1-5-32-545" -and $logonRightLine -notmatch "S-1-1-0") {
                Write-Log "Login properly restricted to primary user" "SUCCESS"
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                exit 0
            } else {
                Write-Log "Login not restricted to primary user - remediation needed" "ERROR"
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                exit 1
            }
        } else {
            # No explicit policy – needs remediation
            Write-Log "No login restriction policy found - remediation needed" "ERROR"
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            exit 1
        }
    } else {
        Write-Log "Could not check security policy" "ERROR"
        exit 1
    }
    
} catch {
    Write-Log "Error in detection: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "Detection completed."