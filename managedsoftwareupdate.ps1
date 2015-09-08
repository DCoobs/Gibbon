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

"Starting...."

#Check that script is being run as administrator; Exit if not.
    If (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
       [Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Warning "You are not running this script as a system administrator!`nPlease re-run this script as an Administrator!"
        Break
    }

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
        Write-Warning "Preflight script encountered an error"
        Exit
        }
    }
Else {"Preflight script does not exist. If this is in error, please ensure script is in the Gibbon install directory"}

"Loading ManagedInstalls.XML"
#Check that ManagedInstalls.XML exists
If (!(Test-Path ($gibbonInstallDir + "\ManagedInstalls.xml")))
    {
    Write-Warning "Could not find ManagedInstalls.XML Exiting..."
    Exit
    }

#Load ManagedInstalls.xml file into variable $managedInstallsXML
[xml]$managedInstallsXML = Get-Content ($gibbonInstallDir + "\ManagedInstalls.xml")

#Parse ManagedInstalls.xml and insert necessary data into variables
$client_Identifier = $managedInstallsXML.dict.ClientIdentifier
[bool]$installWindowsUpdates = [bool]$managedInstallsXML.dict.InstallWindowsUpdates
[DateTime]$lastWindowsUpdateCheck = [DateTime]$managedInstallsXML.dict.LastWindowsUpdateCheck

#if InstallWindowsUpdates is true, install Windows updates (except language packs) but do not reboot.
#import PowerShell Windows Update modules
ipmo ($gibbonInstallDir + "\Resources\WindowsUpdatePowerShellModule\PSWindowsUpdate");
If ($installWindowsUpdates = $True)
    {
    "Checking for available Windows Updates..."
    #Use command on next line for command information
    #Help Get-WUInstall –full
    #Get-WUInstall -NotCategory "Language packs" -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose
    If ($LastExitCode > 0)
        {
        Write-Warning "Windows Updates encountered an error"
        Exit
        }
    ElseIf ($LastExitCode = 0)
        {
        #If successful, update LastWindowsUpdateCheck in ManagedInstalls.XML
        $lastWindowsUpdateCheck = Get-Date
        $managedInstallsXML.DocumentElement.AppendChild($lastWindowsUpdateCheck)
        $managedInstallsXML.Save
        }  
    }


"Finishing..."

#check if postflight script exists and call it if it does exist. Exit if postflight script encounters an error.
"Checking if postflight script exists"
If (Test-Path ($gibbonInstallDir + "\postflight.ps1"))
    {
    "Postflight script exists";
    "Running postflight script";
    Invoke-Expression ($gibbonInstallDir + "\postflight.ps1");
        If ($LastExitCode > 0)
        {
        Write-Warning "Postflight script encountered an error"
        Exit
        }
    }
Else {"Postflight script does not exist. If this is in error, please ensure script is in the Gibbon install directory"}

#Check if there is a pending system reboot, if there is, the computer is restarted. 
$RebootStatus = Get-WURebootStatus
If ($RebootStatus = "localhost: Reboot is not Required")
    {
    "A system reboot is not required"
    }
ElseIf ($RebootStatus = "localhost: Reboot is Required")
    {
    "A system reboot is required. Restarting computer now..."
    Get-WURebootStatus -AutoReboot
    }
Else
    {
    Write-Warning "Encountered an error with Windows update reboot"
    }