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

#Declare gibbonInstallDir variable
$gibbonInstallDir = $env:SystemDrive + "\Progra~1\Gibbon"

#Load ManagedInstalls.xml file into variable $managedInstallsXML
[xml]$managedInstallsXML = Get-Content ($gibbonInstallDir + "\ManagedInstalls.xml")

#Parse ManagedInstalls.xml and insert necessary data into variables
$client_Identifier = $managedInstallsXML.dict.ClientIdentifier
[bool]$installWindowsUpdates = [bool]$managedInstallsXML.dict.InstallWindowsUpdates

#check if preflight script exists and call if it exists
If (Test-Path ($gibbonInstallDir + "\preflight.ps1"))
    {
    Invoke-Expression ($gibbonInstallDir + "\preflight.ps1")
    }
    
    Write-Host "$LastExitCode"
    Write-Host "$installWindowsUpdates"

#if InstallWindowsUpdates is true, check for Windows updates
If ($installWindowsUpdates = $True)
    {
    #import PowerShell Windows Update modules
    ipmo ($gibbonInstallDir + "\Resources\WindowsUpdatePowerShellModule\PSWindowsUpdate");
    Get-WUInstall
    }

#Misc. Variables
#$env:computername = current computername
#$env:systemroot = "C:\windows"  ( or wherever windows was installed )
#$sysroot = $env:SystemRoot | Foreach{$_ -repalce ":","$"}
#$path = "\\" + $env:computername + "\" + $sysroot + "\system32\config"

#Two quotations is print command
#$env:systemroot = c:\windows
#$env:SystemDrive = c: