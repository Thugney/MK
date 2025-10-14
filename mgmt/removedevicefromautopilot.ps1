  Connect-MgGraph -NoWelcome
    
    # Connecting with MSGraph might give a problem if module Microsoft.Graph.Intune is not imported
	Write-Host "`nConnecting to MSGraph`n"		
	Update-MSGraphEnvironment -AppId 9a9fdd0a-4fe1-42ce-8dcf-f9e5c90344b3
	Connect-MSGraph
  
    
    # Paths to files
    $csvPath = "C:\Users\robwol\OneDrive - Modum kommune\Documents\serial.txt"        # This csv-file contains the serial numbers of the AutoPilot devices. Each serial number has to be stored on a seperate line.
    $logPath = ".\notFoundDevices.log"      # Serial numbers that are not found as AutoPilotdevices are stored in this logfile
    
    # Append date and time to logfile
    $dateTimeString = Get-Date -Format "dd-MM-yyy HH:mm:ss"
    " " | Out-File -FilePath $logPath -Append
    $dateTimeString | Out-File -FilePath $logPath -Append
    
    # Read the CSV file
    $serialNumbers = Get-Content -Path $csvPath
    
    # Retrieve al Microsoft Graph devices
    Write-Host "Retrieving all Microsoft Graph devices.`n"	
    $allmgdevices = Get-MgDevice -All
    
    Write-Host "Deleting all devices by serial number.`n"	
    
    # Iterate over each serial number
    foreach ($serialNumber in $serialNumbers) {
        # Get the autopilot device by the serial number
        $apdevice = Get-AutoPilotDevice | Where-Object SerialNumber -eq $serialNumber 
    
        if ($apdevice) { # Device was found
            # Show device information    
            $apdeviceid = $apdevice.azureActiveDirectoryDeviceId
            $apid = $apdevice.id
            $apmanageddeviceid = $apdevice.managedDeviceId
            
            Write-Host "SerialNumber: $serialNumber" -ForegroundColor Blue
            Write-Host "DeviceId: $apdeviceid"
            Write-Host "Id: $apid"
            Write-Host "ManagedDeviceId: $apmanageddeviceid `n"		
            
            # Remove the Intune managed device
            Write-Host "Removing from Intune" 
            try {                
                Remove-IntuneManagedDevice -managedDeviceId $apmanageddeviceid	
            }
            catch {
                Write-Host "Could not remove from Intune devicelist. The device might have been already deleted manually in Intune." -ForegroundColor Red
            }			
    
            # Remove the AutoPilot device
            Write-Host "Removing from AutoPilot"            
            Remove-AutopilotDevice $apid
    
            # Remove the Azure AD device
            Write-Host "Removing from AzureAD`n`n"            
            $mgdevice = $allmgdevices | Where-Object { $_.DeviceId -eq $apdeviceid }
            Remove-MgDevice -DeviceID $mgdevice.id
    
        } else { # Device was not found
            # Write the serial number from the device that was not found to the log file
            $serialNumber | Out-File -FilePath $logPath -Append
            
            # Write the not found serial number to the screen
            Write-Host "Device with SerialNumber '$serialNumber' not found.`n`n" -ForegroundColor Red	
        }
    }    