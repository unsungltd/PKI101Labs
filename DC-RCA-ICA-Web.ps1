#####################################################################################################
# Unsung Ltd Lab 1                                                                                  #
# Version History : V0.1 - Stevie                                                                     #
# Pre-reqs - Assumption that AutomatedLab is installed and working                                  #
# Uses hyper-v by default, believe you can drive vmware desktop and azure too if required.          #
# It _should_ run on a machine with 16GB but might be a push, best on 32GB RAM                      #
# Reason for slightly overcomplicated network is to prevent hyper-v bridging on wireless, this can  #
# cause issues.                                                                                     #
#####################################################################################################
# Globals
$scriptlogFile = ".\DC-RCA-ICA-Web.log"

###################################################################################################
# Log to the screen and record output to a file
###################################################################################################
Function Write-Log($message)
{
    $timeStampString = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "$timeStampString : $message" -ForegroundColor Green
    Add-Content -Value "$timeStampString : $message" -Path $scriptlogFile
}

###################################################################################################
# Log to the screen and record output to a file
###################################################################################################
function Set-LabNAT{
    # NAT Switch
    if (get-vmswitch -name "unsunglabsNAT")
    {
        Write-Log "unsunglabsNAT switch already exists, skipping creation."
    }
    else 
    {
        Write-Log "Creating unsunglabsNAT switch."
        New-VMSwitch -Name "unsunglabsNAT" -SwitchType Internal
        
        Write-Log "Configuring IP address for unsunglabsNAT switch."
        New-NetIPAddress -IPAddress 10.10.20.1 -PrefixLength 24 -InterfaceAlias "vEthernet (unsunglabsNAT)"
        
        Write-Log "Creating NAT gateway 'unsunglabsNAT'."
        New-NetNAT -Name "unsunglabsNAT" -InternalIPInterfaceAddressPrefix 10.10.20.0/24
    }
}


function Set-Lab{
    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:DomainName' = 'unsunglabs.internal'
        'Add-LabMachineDefinition:Memory' = 700MB
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2016 Datacenter (Desktop Experience)'
    }

    New-LabDefinition -Name unsungLab1 -DefaultVirtualizationEngine HyperV -MaxMemory 700MB
    Set-LabInstallationCredential -Username UnsungAdmin -Password "Secret-2025"
    Add-LabDomainDefinition -Name unsunglabs.internal -AdminUser UnsungAdmin -AdminPassword "Secret-2025"
    Add-LabVirtualNetworkDefinition -Name unsunglabsDomain -AddressSpace 10.10.10.0/24 
    Add-LabVirtualNetworkDefinition -Name unsunglabsInfrastructure -AddressSpace 10.10.12.0/24
    Add-LabVirtualNetworkDefinition -Name unsunglabsNat -AddressSpace 10.10.20.0/24

    $netAdapter = @()
    $netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch unsunglabsDomain -Ipv4Address 10.10.10.254
    $netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch unsunglabsInfrastructure -Ipv4Address 10.10.12.254
    $netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch unsunglabsNat -Ipv4Address 10.10.20.10 -Ipv4Gateway 10.10.20.1

    Add-LabMachineDefinition -Name ADDS01 -Roles RootDC -Network unsunglabsDomain -Gateway 10.10.10.254 
    Add-LabMachineDefinition -Name RCA01 -IsDomainJoined:$false -Network unsunglabsDomain -Gateway 10.10.10.254
    Add-LabMachineDefinition -Name ICA01 -IsDomainJoined:$true -Network unsunglabsDomain -Gateway 10.10.10.254
    Add-LabMachineDefinition -Name WEB01 -Roles WebServer -Network unsunglabsDomain -Gateway 10.10.10.254
    Add-LabMachineDefinition -Name WEB02 -Roles WebServer -Network unsunglabsInfrastructure -Gateway 10.10.12.254
    Add-LabMachineDefinition -Name Route1 -Roles Routing -NetworkAdapter $netAdapter 

    Install-Lab
}


Set-LabNAT
Set-Lab

Show-LabDeploymentSummary -Detailed
