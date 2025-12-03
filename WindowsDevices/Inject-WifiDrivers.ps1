<#
.SYNOPSIS
Injiserer HP Wi-Fi-drivere i Windows 11 install.wim 
.DESCRIPTION
Laster ned Wi-Fi-drivere direkte fra HP FTP og injiserer i install.wim.
Krever IKKE HP CMSL - bruker direkte nedlasting.
.PARAMETER ISOPath
Sti til Windows 11 ISO-fil eller mappe med utpakket ISO-innhold

.PARAMETER OutputPath
Sti hvor modifisert install.wim skal lagres

.EXAMPLE
powershell -ExecutionPolicy Bypass -File "J:\Downloads\file\Inject-HPWiFiDrivers.ps1" -ISOPath "J:\Downloads\file\Win11_25H2_Norwegian_x64.iso" -OutputPath "J:\Downloads\file\HPDrivers\WiFiDrivers"

# Default: Only Education and Pro editions
powershell -ExecutionPolicy Bypass -File .\Inject-HPWiFiDrivers.ps1 -ISOPath "C:\Win11.iso" -OutputPath "C:\ModifiedWIM"

# All editions (including Home)
powershell -ExecutionPolicy Bypass -File .\Inject-HPWiFiDrivers.ps1 -ISOPath "C:\Win11.iso" -OutputPath "C:\ModifiedWIM" -AllEditions

# Custom editions
powershell -ExecutionPolicy Bypass -File .\Inject-HPWiFiDrivers.ps1 -ISOPath "C:\Win11.iso" -OutputPath "C:\ModifiedWIM" -EditionsToInject @("Education", "Enterprise")
.NOTES
Author: rowol
Version: 2.0 

Krever: Windows ADK (DISM), Administratorrettigheter
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory=$true)]
    [string]$ISOPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [string]$DriverDownloadPath = "C:\HPDrivers",
    
    [Parameter(Mandatory=$false)]
    [string[]]$EditionsToInject = @("Education", "Pro","Enterprise"),  # Only inject into these editions by default
    
    [Parameter(Mandatory=$false)]
    [switch]$AllEditions,  # Inject into ALL editions if specified
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\MK-LogFiles\HPDriverInjection.log"
)

#region Functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    Add-Content -Path $LogPath -Value $logEntry
    
    switch ($Level) {
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry }
    }
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$Description
    )
    
    Write-Log "Laster ned: $Description"
    Write-Log "  URL: $Url"
    
    # Ensure TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    try {
        # Use Invoke-WebRequest directly (more reliable than BITS for FTP/HTTP)
        $ProgressPreference = 'SilentlyContinue'  # Speed up download
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = 'Continue'
        
        if (Test-Path $OutputPath) {
            $size = [math]::Round((Get-Item $OutputPath).Length / 1MB, 2)
            Write-Log "  Lastet ned: $size MB" -Level "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Log "  Invoke-WebRequest feilet: $_" -Level "WARNING"
        
        # Fallback: Try WebClient (sometimes works when IWR doesn't)
        try {
            Write-Log "  Prover WebClient..." 
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
            
            if (Test-Path $OutputPath) {
                $size = [math]::Round((Get-Item $OutputPath).Length / 1MB, 2)
                Write-Log "  Lastet ned via WebClient: $size MB" -Level "SUCCESS"
                return $true
            }
        }
        catch {
            Write-Log "  WebClient feilet: $_" -Level "WARNING"
            
            # Final fallback: curl.exe (built into Windows 10+)
            try {
                Write-Log "  Prover curl.exe..."
                $curlPath = "curl.exe"
                & $curlPath -L -o $OutputPath $Url 2>&1 | Out-Null
                
                if (Test-Path $OutputPath) {
                    $size = [math]::Round((Get-Item $OutputPath).Length / 1MB, 2)
                    Write-Log "  Lastet ned via curl: $size MB" -Level "SUCCESS"
                    return $true
                }
            }
            catch {
                Write-Log "  curl feilet: $_" -Level "WARNING"
            }
        }
    }
    
    Write-Log "  Kunne ikke laste ned filen" -Level "ERROR"
    return $false
}

function Extract-HPSoftpaq {
    param(
        [string]$SoftpaqPath,
        [string]$ExtractPath
    )
    
    if (-not (Test-Path $ExtractPath)) {
        New-Item -Path $ExtractPath -ItemType Directory -Force | Out-Null
    }
    
    Write-Log "Pakker ut: $SoftpaqPath"
    
    # HP Softpaqs are self-extracting executables
    $process = Start-Process -FilePath $SoftpaqPath -ArgumentList "-e", "-f`"$ExtractPath`"", "-s" -Wait -PassThru -NoNewWindow
    
    # Check if extraction worked
    $infFiles = Get-ChildItem -Path $ExtractPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
    
    if ($infFiles.Count -gt 0) {
        Write-Log "  Fant $($infFiles.Count) driver-filer (.inf)" -Level "SUCCESS"
        return $true
    }
    else {
        Write-Log "  Ingen .inf filer funnet etter utpakking" -Level "WARNING"
        return $false
    }
}

function Get-WiFiDrivers {
    param([string]$DownloadPath)
    
    $driverPath = Join-Path $DownloadPath "WiFiDrivers"
    if (-not (Test-Path $driverPath)) {
        New-Item -Path $driverPath -ItemType Directory -Force | Out-Null
    }
    
    # Direct HP Softpaq URLs for Wi-Fi drivers
    # These are VERIFIED working Softpaqs from HP FTP
    $driverSources = @(
        @{
            # Realtek Wi-Fi drivers - covers many ProBook models
            # Verified: sp155482 from ftp.hp.com
            Name = "Realtek RTL8852/8822/8821 WiFi (Oct 2024)"
            URL = "https://ftp.hp.com/pub/softpaq/sp155001-155500/sp155482.exe"
            Folder = "Realtek_WiFi"
        },
        @{
            # Intel Wi-Fi 6E AX211 driver
            # Verified: sp138607 from ftp.hp.com  
            Name = "Intel Wi-Fi 6E AX211 (Mar 2022)"
            URL = "https://ftp.hp.com/pub/softpaq/sp138501-139000/sp138607.exe"
            Folder = "Intel_AX211"
        },
        @{
            # Full driver pack for ProBook G10 - includes WiFi
            # Verified: sp145027 from ftp.hp.com
            Name = "HP ProBook G10 Driver Pack (Feb 2023)"
            URL = "https://ftp.hp.com/pub/softpaq/sp145001-145500/sp145027.exe"
            Folder = "HP_ProBook_G10_Pack"
        },
        @{
            # WinPE driver pack - contains network drivers for deployment
            # Verified: sp155634 from ftp.hp.com (WinPE 10/11 v3.00)
            Name = "HP WinPE 10/11 Driver Pack v3.00 (Mar 2025)"
            URL = "https://ftp.hp.com/pub/softpaq/sp155501-156000/sp155634.exe"
            Folder = "HP_WinPE_Drivers"
        }
    )
    
    $downloadedPaths = @()
    
    foreach ($driver in $driverSources) {
        $softpaqFile = Join-Path $DownloadPath "$($driver.Folder).exe"
        $extractPath = Join-Path $driverPath $driver.Folder
        
        # Skip if already extracted
        if (Test-Path $extractPath) {
            $existingInf = Get-ChildItem -Path $extractPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
            if ($existingInf.Count -gt 0) {
                Write-Log "Bruker eksisterende: $($driver.Name)"
                $downloadedPaths += $extractPath
                continue
            }
        }
        
        # Download
        $downloaded = Download-File -Url $driver.URL -OutputPath $softpaqFile -Description $driver.Name
        
        if ($downloaded) {
            # Extract
            $extracted = Extract-HPSoftpaq -SoftpaqPath $softpaqFile -ExtractPath $extractPath
            
            if ($extracted) {
                $downloadedPaths += $extractPath
            }
            
            # Clean up .exe to save space
            Remove-Item -Path $softpaqFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    return $downloadedPaths
}
#endregion

#region Main Script
try {
    Write-Log "=========================================="
    Write-Log "HP Wi-Fi Driver Injection Script v2.0"
    Write-Log "=========================================="
    
    # Check admin
    if (-not (Test-AdminPrivileges)) {
        throw "Skriptet maa kjoeres som administrator"
    }
    Write-Log "Administratorrettigheter bekreftet"
    
    # Create directories
    $mountPath = "C:\WIM_Mount"
    @($OutputPath, $DriverDownloadPath, $mountPath) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
            Write-Log "Opprettet mappe: $_"
        }
    }
    
    # Clean mount point if it has leftover content
    if ((Get-ChildItem $mountPath -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Log "Rydder mount-punkt fra tidligere kjoering..."
        try {
            Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction Stop
        }
        catch {
            # Try DISM command directly
            dism /Unmount-Wim /MountDir:$mountPath /Discard 2>$null
        }
        Remove-Item -Path "$mountPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Handle ISO vs folder
    $sourcePath = $ISOPath
    $isoMounted = $false
    $mountedDrive = $null
    
    if ($ISOPath -match "\.iso$" -and (Test-Path $ISOPath)) {
        Write-Log "Monterer ISO: $ISOPath"
        $mountResult = Mount-DiskImage -ImagePath $ISOPath -PassThru
        Start-Sleep -Seconds 2
        $mountedDrive = ($mountResult | Get-Volume).DriveLetter
        $sourcePath = "${mountedDrive}:\"
        $isoMounted = $true
        Write-Log "ISO montert som stasjon $mountedDrive`:"
    }
    elseif (-not (Test-Path $ISOPath)) {
        throw "ISO-fil ikke funnet: $ISOPath"
    }
    
    # Find install.wim or install.esd
    $installWIM = Join-Path $sourcePath "sources\install.wim"
    $installESD = Join-Path $sourcePath "sources\install.esd"
    
    if (Test-Path $installWIM) {
        Write-Log "Fant install.wim"
        $workingWIM = Join-Path $OutputPath "install.wim"
        Write-Log "Kopierer install.wim til arbeidskatalog..."
        Copy-Item -Path $installWIM -Destination $workingWIM -Force
        
        # CRITICAL: Remove read-only attribute from copied WIM
        Write-Log "Fjerner skrivebeskyttelse fra install.wim..."
        Set-ItemProperty -Path $workingWIM -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        & attrib -R `"$workingWIM`"
        
        # Verify it's writable
        if ((Get-Item $workingWIM).IsReadOnly) {
            throw "Kunne ikke fjerne skrivebeskyttelse fra install.wim"
        }
        Write-Log "Skrivebeskyttelse fjernet" -Level "SUCCESS"
        
        $installWIM = $workingWIM
    }
    elseif (Test-Path $installESD) {
        Write-Log "Fant install.esd - konverterer til install.wim..."
        $workingWIM = Join-Path $OutputPath "install.wim"
        
        # Get available indexes
        $esdInfo = Get-WindowsImage -ImagePath $installESD
        Write-Log "Tilgjengelige images i ESD:"
        $esdInfo | ForEach-Object { Write-Log "  Index $($_.ImageIndex): $($_.ImageName)" }
        
        # Export all indexes
        foreach ($image in $esdInfo) {
            Write-Log "Eksporterer index $($image.ImageIndex)..."
            Export-WindowsImage -SourceImagePath $installESD -SourceIndex $image.ImageIndex -DestinationImagePath $workingWIM -CompressionType Maximum
        }
        
        $installWIM = $workingWIM
    }
    else {
        throw "Verken install.wim eller install.esd funnet i $sourcePath\sources"
    }
    
    # Download drivers
    Write-Log ""
    Write-Log "=========================================="
    Write-Log "Laster ned Wi-Fi-drivere fra HP"
    Write-Log "=========================================="
    
    $driverPaths = Get-WiFiDrivers -DownloadPath $DriverDownloadPath
    
    if ($driverPaths.Count -eq 0) {
        throw "Ingen drivere lastet ned - sjekk nettverkstilkobling"
    }
    
    Write-Log ""
    Write-Log "Lastet ned $($driverPaths.Count) driver-pakker"
    
    # Inject drivers into each image index
    Write-Log ""
    Write-Log "=========================================="
    Write-Log "Injiserer drivere i install.wim"
    Write-Log "=========================================="
    
    $wimInfo = Get-WindowsImage -ImagePath $installWIM
    
    # Filter editions unless -AllEditions is specified
    if (-not $AllEditions) {
        Write-Log "Filtrerer etter utgaver: $($EditionsToInject -join ', ')"
        $wimInfo = $wimInfo | Where-Object { 
            $imageName = $_.ImageName
            $EditionsToInject | ForEach-Object { $imageName -match $_ } | Where-Object { $_ -eq $true }
        }
        Write-Log "Fant $($wimInfo.Count) utgaver som matcher"
    }
    
    foreach ($image in $wimInfo) {
        Write-Log ""
        Write-Log "Behandler: $($image.ImageName) (Index $($image.ImageIndex))"
        
        if ($PSCmdlet.ShouldProcess($image.ImageName, "Injiser drivere")) {
            try {
                # Mount
                Write-Log "  Monterer image..."
                Mount-WindowsImage -ImagePath $installWIM -Index $image.ImageIndex -Path $mountPath | Out-Null
                
                # Add each driver folder
                foreach ($driverFolder in $driverPaths) {
                    if (Test-Path $driverFolder) {
                        Write-Log "  Legger til drivere fra: $(Split-Path $driverFolder -Leaf)"
                        try {
                            $result = Add-WindowsDriver -Path $mountPath -Driver $driverFolder -Recurse -ForceUnsigned -ErrorAction SilentlyContinue
                            $addedCount = ($result | Measure-Object).Count
                            if ($addedCount -gt 0) {
                                Write-Log "    Lagt til $addedCount drivere" -Level "SUCCESS"
                            }
                        }
                        catch {
                            Write-Log "    Advarsel: $_" -Level "WARNING"
                        }
                    }
                }
                
                # Unmount and save
                Write-Log "  Lagrer endringer..."
                Dismount-WindowsImage -Path $mountPath -Save | Out-Null
                Write-Log "  Ferdig med index $($image.ImageIndex)" -Level "SUCCESS"
            }
            catch {
                Write-Log "  FEIL: $_" -Level "ERROR"
                Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction SilentlyContinue
            }
        }
    }
    
    # Cleanup
    if ($isoMounted) {
        Write-Log ""
        Write-Log "Demonterer ISO..."
        Dismount-DiskImage -ImagePath $ISOPath | Out-Null
    }
    
    # Final summary
    $finalWIM = Join-Path $OutputPath "install.wim"
    $wimSize = [math]::Round((Get-Item $finalWIM).Length / 1GB, 2)
    
    Write-Log ""
    Write-Log "=========================================="
    Write-Log "FERDIG!" -Level "SUCCESS"
    Write-Log "=========================================="
    Write-Log ""
    Write-Log "Modifisert install.wim: $finalWIM"
    Write-Log "Storrelse: $wimSize GB"
    Write-Log ""
    Write-Log "NESTE STEG:"
    Write-Log "1. Kopier til USB:"
    Write-Log "   copy `"$finalWIM`" E:\sources\install.wim"
    Write-Log ""
    Write-Log "2. Eller lag ny USB med Rufus og bytt ut install.wim"
    Write-Log "=========================================="
}
catch {
    Write-Log "KRITISK FEIL: $_" -Level "ERROR"
    Write-Log $_.ScriptStackTrace -Level "ERROR"
    
    # Cleanup
    if (Test-Path $mountPath) {
        try { Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction SilentlyContinue } catch {}
        try { dism /Unmount-Wim /MountDir:$mountPath /Discard 2>$null } catch {}
    }
    
    if ($isoMounted -and $ISOPath) {
        try { Dismount-DiskImage -ImagePath $ISOPath -ErrorAction SilentlyContinue } catch {}
    }
    
    exit 1
}
#endregion
