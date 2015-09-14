<# 
.SYNOPSIS 
    This script reads the ManagedInstalls.XML which contains system preferences and stores information from last run for Gibbon. 
.NOTES 
    Author     : Drew Coobs - coobs1@illinois.edu 
#>
##############################################################################
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
##############################################################################

#Enabling script parameters (allows verbose, debug, checkonly, installonly)
[CmdletBinding()]
Param(
    [switch]$checkOnly,
	[switch]$installOnly
)

###########################################################
###   NETWORK CONNECTION TEST   ###########################
########################################################### 

$networkUp = (Test-NetConnection -InformationLevel Quiet)

If ($networkUp)
    {
    Write-Verbose "Network connection validated"
    }
Else
    {
    Write-Verbose "Could not validate network connection. Exiting..."
    Exit
    }

###########################################################
###   END OF NETWORK CONNECTION TEST   ####################
########################################################### 

###########################################################
###   CONSTANT VARIABLES   ################################
###########################################################

#Declare Gibbon install directory variable
$gibbonInstallDir = $env:SystemDrive + "\Progra~1\Gibbon"

#Declare path of ManagedInstalls.XML
$gibbonManagedInstallsXMLPath = (Join-Path $gibbonInstallDir ManagedInstalls.xml)

#Declare path of manifest


###########################################################
###   END OF CONSTANT VARIABLES   #########################
###########################################################

Write-Verbose "Starting...."

#Check that script is being run as administrator; Exit if not.
    If (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
       [Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Warning "You are not running this script as a system administrator!`nPlease re-run this script as an Administrator!"
        Break
    }


################################################################################################
### MANAGEDINSTALLS.XML ########################################################################
################################################################################################
 
Write-Verbose "Loading ManagedInstalls.XML"
#Check that ManagedInstalls.XML exists
If (!(Test-Path ($gibbonManagedInstallsXMLPath)))
    {
    Write-Warning "Could not find ManagedInstalls.XML Exiting..."
    Exit
    }

#Load ManagedInstalls.xml file into variable $managedInstallsXML
[xml]$managedInstallsXML = Get-Content ($gibbonManagedInstallsXMLPath)

#Parse ManagedInstalls.xml and insert necessary data into variables
$client_Identifier = $managedInstallsXML.dict.ClientIdentifier
$installWindowsUpdates = $managedInstallsXML.dict.InstallWindowsUpdates
$windowsUpdatesOnly = $managedInstallsXML.dict.WindowsUpdatesOnly
[int]$daysBetweenWindowsUpdates = [int]$managedInstallsXML.dict.DaysBetweenWindowsUpdates
[DateTime]$lastWindowsUpdateCheck = [DateTime]$managedInstallsXML.dict.LastWindowsUpdateCheck
$logFilePath = $managedInstallsXML.dict.LogFile
$loggingEnabled = $managedInstallsXML.dict.LoggingEnabled
$softwareRepoURL = $managedInstallsXML.dict.SoftwareRepoURL

#convert boolean values in XML from strings to actual boolean
[bool]$installWindowsUpdates = [System.Convert]::ToBoolean($installWindowsUpdates)
[bool]$windowsUpdatesOnly = [System.Convert]::ToBoolean($windowsUpdatesOnly)
[bool]$loggingEnabled = [System.Convert]::ToBoolean($loggingEnabled)

################################################################################################
### END OF MANAGEDINSTALLS.XML #################################################################
################################################################################################

###########################################################
###   LOGGING   ###########################################
###########################################################

#Create log folder if it doesn't exist.
New-Item -ItemType Directory -Force -Path $logFilePath | Out-Null

Start-Transcript -path (Join-Path $logFilePath -ChildPath Gibbon.log) -Append

###########################################################
###   END OF LOGGING   ####################################
###########################################################

############################################################################################
### PREFLIGHT SCRIPT #######################################################################
######################## ###################################################################

#check if preflight script exists and call it if it does exist. Exit if preflight script encounters an error.
Write-Verbose "Checking if preflight script exists"
If (Test-Path (Join-Path $gibbonInstallDir -ChildPath preflight.ps1))
    {
    Write-Verbose "Preflight script exists";
    Write-Verbose "Running preflight script";
    Invoke-Expression (Join-Path $gibbonInstallDir -ChildPath \preflight.ps1);
        If ($LastExitCode > 0)
        {
        Write-Warning "Preflight script encountered an error"
        Exit
        }
    }
Else {Write-Verbose "Preflight script does not exist. If this is in error, please ensure script is in the Gibbon install directory"}

############################################################################################
### END OF PREFLIGHT SCRIPT ################################################################
############################################################################################

#########################################################################################################################################################################
### OBTAIN INITIAL MANIFEST #############################################################################################################################################
#########################################################################################################################################################################

#import BitsTransfer module
IPMO BitsTransfer

If (-Not(($windowsUpdatesOnly)))
    {
    Write-Host "Getting manifest $client_Identifier"
    
    #Download manifest matching client_identifier in ManagedInstalls.XML. If unable to find it on server, attempt to download site-default manifest.
    Try
        {
        Start-BitsTransfer -Source ($softwareRepoURL + "/manifests/" + $client_Identifier + ".xml") -Destination ($gibbonInstallDir + "\GibbonInstalls\manifest\" + $client_Identifier + ".xml") -TransferType Download -ErrorAction Stop
        Write-Verbose "Using manifest $client_Identifier"
        $initialManifest = $client_Identifier
        }
    Catch
        {
        Write-Verbose "Manifest $client_Identifier not found. Attempting site-default manifest instead..."
        $noClientIdentifier = $True
        }
    
    If ($noClientIdentifier)
        {
        Try
            {
            Start-BitsTransfer -Source ($softwareRepoURL + "/manifests/site-default.xml") -Destination ($gibbonInstallDir + "\GibbonInstalls\manifest\site-default.xml") -TransferType Download -ErrorAction Stop
            Write-Verbose "Using manifest site-default"
            $initialManifest = "site-default"
            }
        Catch
            {
            Write-Verbose "Unable to locate $client_Identifier or site-default manifests. Skipping Gibbon installs..."
            $haveManifest = $False
            }
        }
    }

#########################################################################################################################################################################
### END OF OBTAIN INITIAL MANIFEST ######################################################################################################################################
#########################################################################################################################################################################

#################################################
### OBTAIN NESTED MANIFESTS #####################
#################################################

#################################################
### END OF OBTAIN NESTED MANIFESTS ##############
#################################################

##################################################################################################################
### OBTAIN LIST OF GIBBON SOFTWARE INSTALLS ######################################################################
##################################################################################################################

If (-Not(($windowsUpdatesOnly)))
    {

#Load $manifest.xml file into variable $manifestXML
[xml]$initialManifestXML = Get-Content ($gibbonInstallDir + "\GibbonInstalls\manifest\" + $initialManifest + ".xml")

#load list of Gibbon software installs from initial manifest
[array]$gibbonSoftware = $initialManifestXML.dict.software.program

#create variable for each software in array
for($i=0; $i -lt $gibbonSoftware.count; $i++)
{
    New-Variable -Name "gibbonSoftware$i" -Value $gibbonSoftware[$i]
}

# get a list of gibbonSoftware variables
Get-Variable gibbonSoftwar*

    }

##################################################################################################################
### END OF OBTAIN LIST OF GIBBON SOFTWARE INSTALLS ###############################################################
##################################################################################################################

###########################################################################################
### WINDOWS UPDATES #######################################################################
###########################################################################################

#import PowerShell Windows Update modules
IPMO (Join-Path $gibbonInstallDir -ChildPath Resources\WindowsUpdatePowerShellModule\PSWindowsUpdate)

#Check if $installWindowsUpdates is true in ManagedInstalls.XML. Skip Windows Updates if False.
If ($installWindowsUpdates -or $windowsUpdatesOnly)
    {
    #Check if Windows Updates been run in last $daysBetweenWindowsUpdates day(s). If so, skip Windows Updates.
    $windowsUpdateTimeSpan = (new-timespan -days $daysBetweenWindowsUpdates)
    If (((Get-Date) - $lastWindowsUpdateCheck) -gt $windowsUpdateTimeSpan)
        {
        Write-Verbose "Checking for available Windows Updates..."
        #Use command on next line for command information
        #Help Get-WUInstall –full
        #if checkonly is enabled, only download updates, otherwise, install Windows Updates (except for Language Packs)
        If ($checkOnly)
            {
            Get-WUInstall -NotCategory "Language packs" -MicrosoftUpdate -DownloadOnly -AcceptAll -IgnoreReboot -Verbose
            }
        Else
            {
            Get-WUInstall -NotCategory "Language packs" -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose
            
            #Update LastWindowsUpdateCheck in ManagedInstalls.XML
            $managedInstallsXML.SelectSingleNode("//LastWindowsUpdateCheck").InnerText = (Get-Date)
            #save changes to ManagedInstalls.XML
            $managedInstallsXML.Save($gibbonInstallDir + "\ManagedInstalls.xml")
            }
        }
    }

###########################################################################################
### END OF WINDOWS UPDATES ################################################################
###########################################################################################

Write-Verbose "Finishing..."

##############################################################################################
### POSTFLIGHT SCRIPT ########################################################################
######################### ####################################################################

#check if postflight script exists and call it if it does exist. Exit if postflight script encounters an error.
Write-Verbose "Checking if postflight script exists"
If (Test-Path (Join-Path $gibbonInstallDir -ChildPath postflight.ps1))
    {
    Write-Verbose "Postflight script exists";
    Write-Verbose "Running postflight script";
    Invoke-Expression (Join-Path $gibbonInstallDir -ChildPath postflight.ps1);
        If ($LastExitCode > 0)
        {
        Write-Warning "Postflight script encountered an error"
        Exit
        }
    }
Else {Write-Verbose "Postflight script does not exist. If this is in error, please ensure script is in the Gibbon install directory"}

##############################################################################################
### END OF POSTFLIGHT SCRIPT #################################################################
##############################################################################################

################################################################################################
### PENDING REBOOT CHECK #######################################################################
################################################################################################
 
#Check if there is a pending system reboot, if there is, the computer is restarted. 
[bool]$RebootStatus = Get-WURebootStatus -silent
If ($RebootStatus)
    {
    Write-Verbose "A system reboot is required. Restarting computer now..."
    Get-WURebootStatus -AutoReboot
    }
Else
    {
    Write-Verbose "A system reboot is not required"
    }

################################################################################################
### END OF PENDING REBOOT CHECK ################################################################
################################### ############################################################