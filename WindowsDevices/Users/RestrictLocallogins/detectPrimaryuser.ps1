try {
    Write-Output "Starting Primary User Login Restriction Detection"

    # Get primary user UPN (machine-level, no login required)
    $primaryUserUPN = $null
    $enrollmentPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
    $enrollmentKeys = Get-ChildItem -Path $enrollmentPath -ErrorAction SilentlyContinue
    
    foreach ($key in $enrollmentKeys) {
        $keyPath = $key.PSPath
        try {
            $upn = Get-ItemProperty -Path $keyPath -Name "UPN" -ErrorAction SilentlyContinue
            if ($upn.UPN) {
                $primaryUserUPN = $upn.UPN
                Write-Output "Found primary user from Intune enrollment: $primaryUserUPN"
                break
            }
        } catch {
            continue
        }
    }
    
    # Fallback: dsregcmd (machine-level)
    if (-not $primaryUserUPN) {
        try {
            $dsregStatus = dsregcmd /status
            $userEmailLine = $dsregStatus | Where-Object { $_ -match "UserEmail\s*:" }
            if ($userEmailLine) {
                $primaryUserUPN = ($userEmailLine -split ":")[1].Trim()
                Write-Output "Found primary user from dsregcmd: $primaryUserUPN"
            }
        } catch {}
    }
    
    if (-not $primaryUserUPN) {
        Write-Output "Could not determine primary user"
        exit 1
    }
    
    # Get primary user SID (reliable NTAccount method, no login required post-enrollment)
    try {
        $account = "AzureAD\$primaryUserUPN"
        $ntAccount = New-Object System.Security.Principal.NTAccount($account)
        $userSID = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
        Write-Output "Found primary user SID: $userSID"
    } catch {
        Write-Output "Could not determine primary user SID: $($_.Exception.Message)"
        exit 1
    }
    
    # Check current security policy
    $tempFile = "$env:TEMP\secpol_check.cfg"
    secedit /export /cfg $tempFile /quiet
    
    if (Test-Path $tempFile) {
        $policyContent = Get-Content $tempFile
        $logonRightLine = $policyContent | Where-Object { $_ -match "^SeInteractiveLogonRight\s*=" }
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        if ($logonRightLine) {
            # Must include user SID + admins, exclude Users/Everyone
            $hasUserSID = $logonRightLine -match [regex]::Escape("*$userSID")
            $hasAdmins = $logonRightLine -match "S-1-5-32-544"
            $hasUnwanted = ($logonRightLine -match "S-1-5-32-545") -or ($logonRightLine -match "S-1-1-0")
            
            if ($hasUserSID -and $hasAdmins -and -not $hasUnwanted) {
                Write-Output "Login properly restricted to primary user"
                exit 0
            } else {
                Write-Output "Login not restricted properly to primary user - remediation needed"
                exit 1
            }
        } else {
            Write-Output "No login restriction policy found - remediation needed"
            exit 1
        }
    } else {
        Write-Output "Could not check security policy"
        exit 1
    }
    
} catch {
    Write-Output "Error in detection: $($_.Exception.Message)"
    exit 1
}

Write-Output "Detection completed."