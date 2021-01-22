# Create Series of Hyper-V VMs for build testing


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Functions

#----------------------------
FUNCTION Get-ScriptDirectory
#----------------------------
    { 
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
    } 
    #end function Get-ScriptDirectory


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

#Get the location the script is running from
	Write-Host "Getting Script Dir..."
	$scriptFolder = Get-ScriptDirectory
	Write-Host "Script Dir set to: $ScriptFolder"


# Get the Computer Name so we can handle settings per machine
$HostName = $($env:COMPUTERNAME)
Write-Host "Host Name: $HostName"

$VMLocation = "C:\Hyper-V"
$VMNetwork = "External"

$VMMemory = 2048MB
$VMDiskSize = 160GB
$CSVFileMM1 = "$ScriptFolder\VMTIDs_MM1.csv"

IF(Test-Path $CSVFileMM1)
    {
    Remove-Item -Path $CSVFileMM1 -Force
    }



    FOR ($v=0;$v -le 20; $v++)
        {
        $VMNum = $v.ToString("00")
        $VMName = "VMMDM0$VMNum"

        # Create the Virtual Machine
        New-VM -Name $VMName -Generation 2 -BootDevice NetworkAdapter -MemoryStartupBytes $VMMemory -SwitchName $VMNetwork -Path $VMLocation -NoVHD -Verbose
        
        # Create and attach the virtual hard disk
        New-VHD -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" -SizeBytes $VMDiskSize -Verbose
        Add-VMHardDiskDrive -VMName $VMName -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" -Verbose

        # Set the vCPU to dual core
        Set-VMProcessor -VMName $VMName -Count 2

        # Enable Guest Services
        Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $VMName

        # Turn off Dynamic Memory
        Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $FALSE

        # Set a static MAC address (so we can create a CSV to import into ConfigMgr if needed)
        Set-VMNetworkAdapter -VMName $VMName -StaticMacAddress "00:15:6D:20:20:$VMNum"

        # Set the VM's resolution
        Set-VMVideo -VMName $VMName -ResolutionType Single -HorizontalResolution 1440 -VerticalResolution 900

        # Disable automatic checkpoints
        Set-VM -VMName $VMName -AutomaticCheckpointsEnabled $false

        # Get the VM's Serial Number
        $SN = (Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemSettingData | where {$_.ElementName -like $VMName}).BIOSSerialNumber

        # Add this VM to a CSV that we can import into ConfigMgr
        Add-Content -Value "$TID,$SN,00:15:6D:20:20:$VMNum" -Path $CSVFileMM1

        }


# Finished