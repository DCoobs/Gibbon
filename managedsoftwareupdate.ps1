<# 
.SYNOPSIS 
    This script reads the ManagedInstalls.XML which contains system preferences and stores information from last run for Gibbon. 
.NOTES 
    Author     : Drew Coobs - coobs1@illinois.edu 
#>
#
# Copyright 2015 Drew Coobs.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Running managedsoftwareupdate"

#Declare gibbonInstallDir variable
$gibbonInstallDir = $env:SystemDrive + "\Progra~1\Gibbon"

#check if preflight script exists and call it if it does exist. Exit if preflight script encounters an error.
"Checking if preflight script exists"
If (Test-Path ($gibbonInstallDir + "\preflight.ps1"))
    {
    "Preflight script exists";
    "Running preflight script";
    Invoke-Expression ($gibbonInstallDir + "\preflight.ps1");
        If ($LastExitCode > 0)
        {
        Write-Host "Preflight script encountered an error"
        Exit
        }
    }
Else {"Preflight script does not exist. If this is in error, please ensure script is in the Gibbon install directory"}

"Loading ManagedInstalls.XML"
#Check that ManagedInstalls.XML exists
If (!(Test-Path ($gibbonInstallDir + "\ManagedInstalls.xml")))
    {
    "Could not find ManagedInstalls.XML Exiting..."
    Exit
    }

#Load ManagedInstalls.xml file into variable $managedInstallsXML
[xml]$managedInstallsXML = Get-Content ($gibbonInstallDir + "\ManagedInstalls.xml")

#Parse ManagedInstalls.xml and insert necessary data into variables
$client_Identifier = $managedInstallsXML.dict.ClientIdentifier
[bool]$installWindowsUpdates = [bool]$managedInstallsXML.dict.InstallWindowsUpdates
$lastWindowsUpdateCheck = $managedInstallsXML.dict.LastWindowsUpdateCheck
    

#if InstallWindowsUpdates is true, install Windows updates (except language packs) but do not reboot
If ($installWindowsUpdates = $True)
    {
    #import PowerShell Windows Update modules
    ipmo ($gibbonInstallDir + "\Resources\WindowsUpdatePowerShellModule\PSWindowsUpdate");
    #Uncomment next line for command information
    #Help Get-WUInstall –full
    #Get-WUInstall -NotCategory "Language packs" -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose
    If ($LastExitCode > 0)
        {
        Write-Host "Windows Updates encountered an error"
        Exit
        }  
    }

#check if postflight script exists and call it if it does exist. Exit if postflight script encounters an error.
"Checking if postflight script exists"
If (Test-Path ($gibbonInstallDir + "\postflight.ps1"))
    {
    "Postflight script exists";
    "Running postflight script";
    Invoke-Expression ($gibbonInstallDir + "\postflight.ps1");
        If ($LastExitCode > 0)
        {
        Write-Host "Postflight script encountered an error"
        Exit
        }
    }
Else {"Postflight script does not exist. If this is in error, please ensure script is in the Gibbon install directory"}

#If there is a pending Windows Update reboot, it reboots the computer. 
Get-WURebootStatus -AutoReboot



#Misc. Variables
#$env:computername = current computername
#$env:systemroot = "C:\windows"  ( or wherever windows was installed )
#$sysroot = $env:SystemRoot | Foreach{$_ -repalce ":","$"}
#$path = "\\" + $env:computername + "\" + $sysroot + "\system32\config"

#Two quotations is print command
#$env:systemroot = c:\windows
#$env:SystemDrive = c: