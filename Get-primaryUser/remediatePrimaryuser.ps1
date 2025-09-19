<#
.SYNOPSIS
Sjekker om Windows-pålogging er begrenset til primærbruker og administratorer.

.DESCRIPTION
Dette skriptet brukes i Intune Proactive Remediations for å kontrollere om enheten har riktig konfigurasjon for påloggingsrettigheter.
Det henter primærbrukerens UPN fra Intune-registeret og leser sikkerhetspolicyen for å verifisere at kun spesifikke SIDs har rett til interaktiv pålogging.

.NOTES
Author: robwol

#>
 param(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    # Enhanced logging: Append to file for persistence
    $logFile = "$env:TEMP\PrimaryUserLogonRestriction_$(Get-Date -Format 'yyyyMMdd').log"
    $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

try {
    Write-Log "Starting Primary User Login Restriction Script"

    # Get the primary user (first user who enrolled the device in Intune)
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
        throw "Could not determine primary user for this device"
    }

    # Improvement 1: Add Autopilot Enrollment Check
    Write-Log "Validating Autopilot enrollment..."
    $autopilotCache = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache" -Name "PolicyJsonCache" -ErrorAction SilentlyContinue
    $approvedGUIDs = @("YourApprovedGUID1", "YourApprovedGUID2")  # Replace with your actual approved ZtdCorrelationId values
    if ($autopilotCache) {
        try {
            $policyJson = $autopilotCache.PolicyJsonCache | ConvertFrom-Json
            $ztdCorrelationId = $policyJson.ZtdCorrelationId
            if ($ztdCorrelationId -notin $approvedGUIDs) {
                throw "Device not enrolled via approved Autopilot profile (ID: $ztdCorrelationId)"
            }
            Write-Log "Autopilot enrollment validated: $ztdCorrelationId"
        } catch {
            Write-Log "Error parsing Autopilot policy: $($_.Exception.Message)" "WARNING"
        }
    } else {
        Write-Log "No Autopilot cache found - proceeding with caution" "WARNING"
    }

    # Get user SID
    Write-Log "Looking up user SID for: $primaryUserUPN"
    $userSID = $null
    $usernamePrefix = $primaryUserUPN.Split('@')[0].Replace('.', '')

    # Method 1: Match local profile
    $profileList = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction SilentlyContinue | Where-Object { $_.ProfileImagePath -like "*Users*" }
    foreach ($profile in $profileList) {
        $profilePath = $profile.ProfileImagePath
        $username = Split-Path $profilePath -Leaf
        # Flexible matching: check if username is in UPN or UPN prefix is in username
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

    # Improvement 2: Additional SID Fallback - IdentityStore Cache
    if (-not $userSID) {
        Write-Log "Attempting SID lookup via IdentityStore Cache..."
        $identityStorePath = "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache"
        # Common Provider GUID for Azure AD/Entra ID
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
        throw "Could not determine valid user SID for primary user: $primaryUserUPN"
    }

    Write-Log "Primary User: $primaryUserUPN"
    Write-Log "Primary User SID: $userSID"

    if ($WhatIf) {
        Write-Log "WHATIF: Would configure login rights for user SID: $userSID" "WHATIF"
        Write-Log "WHATIF: Would block all other users from logging in" "WHATIF"
        return
    }

    # Export current security policy
    $tempFile = "$env:TEMP\secpol.cfg"
    $backupFile = "$env:TEMP\secpol_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').cfg"
    
    Write-Log "Exporting current security policy..."
    secedit /export /cfg $tempFile /quiet
    
    if (Test-Path $tempFile) {
        Copy-Item $tempFile $backupFile
        Write-Log "Security policy backed up to: $backupFile"
        
        # Read current policies
        $policyContent = Get-Content $tempFile
        
        # Find the line for "Allow log on locally" (SeInteractiveLogonRight)
        $newPolicyContent = @()
        $logonRightSet = $false
        
        foreach ($line in $policyContent) {
            if ($line -match "^SeInteractiveLogonRight\s*=") {
                # Replace with only the primary user's SID + administrators
                $newLine = "SeInteractiveLogonRight = *$userSID,*S-1-5-32-544"
                $newPolicyContent += $newLine
                $logonRightSet = $true
                Write-Log "Updated SeInteractiveLogonRight: $newLine"
            } else {
                $newPolicyContent += $line
            }
        }
        
        # If SeInteractiveLogonRight wasn't found, add it
        if (-not $logonRightSet) {
            $newPolicyContent += "SeInteractiveLogonRight = *$userSID,*S-1-5-32-544"
            Write-Log "Added SeInteractiveLogonRight for primary user and administrators"
        }
        
        # Save modified policies
        $newPolicyContent | Set-Content $tempFile
        
        # Apply the new policy
        Write-Log "Applying new security policy (first pass)..."
        $result = secedit /configure /db secedit.sdb /cfg $tempFile /quiet
        
        if ($LASTEXITCODE -eq 0) {
            # Improvement 3: Apply Policy Twice with Delay
            Start-Sleep -Seconds 30
            Write-Log "Re-applying policy for reliability (second pass)..."
            secedit /configure /db secedit.sdb /cfg $tempFile /quiet
            gpupdate /force
            Write-Log "Security policy applied successfully!" "SUCCESS"
            Write-Log "Only the primary user ($primaryUserUPN) and local Administrators can now log in to this device."
            Write-Log "Policy backup saved to: $backupFile"
        } else {
            throw "Failed to apply security policy. Exit code: $LASTEXITCODE"
        }
        
        # Clean up temp file
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
    } else {
        throw "Failed to export current security policy"
    }
    
} catch {
    Write-Log "Script failed: $($_.Exception.Message)" "ERROR"
    throw
}

Write-Log "Script completed successfully!"
Write-Log "NOTE: Changes take effect immediately. Other users will be blocked from logging in."
Write-Log "To restore access for all users, use the backup: $backupFile"