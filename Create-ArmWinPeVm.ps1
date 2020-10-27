#requires -modules AzureRM

<#
    .SYNOPSIS
        Creates an Azure VM template with a customized WinPE as the source image disk.

    .PARAMETER SubscriptionId
        Azure Subscription ID to connect.
    
    .PARAMETER StorageAccountName
        Name of the storage account to connect.

    .PARAMETER VhdPath
        Path of the URL that points to the location of the VHD in Azure.

    .PARAMETER VmNamePrefix
        The start of the VM's name, which will have an incrementing number appended.

    .PARAMETER vmSize
        Size of VM to deploy. Side note: 'Standard_A1' and other smaller sizes are not 
        recommended for MDT deployments in Azure as it is too small to successfully deploy.

    .PARAMETER DomNamePrefix
        Start of the Domain Name string property for Azure VMs.

    .PARAMETER VnetSubnet
        The subnet of the target vNet definition if creating.

    .PARAMETER VnetSubnetConfig
        The subnet of the target vNet if creating.

    .PARAMETER adminUsername
        Name of Administrative user for the Azure VM.  Cannot be "Administrator" or "Admin"

    .PARAMETER adminPassword
        Password for the Administrative user.

    .PARAMETER OsDiskPath
        Path of the URL that points to the location of the new VHD in Azure.

    .PARAMETER VnetSubnet
        Subnet string for creating a new vNet definition.

    .PARAMETER VnetSubnetConfig
        Subnet string for create a new vNet subnet configuration.

    .PARAMETER MAG
        Disk label for Azure VM.

    .EXAMPLE
        .\Create-ArmWinPeVm.ps1 -SubscriptionId "[SUBSCRIPTION-GUID]" -StorageAccountName "winpe" `
        -VhdPath "vhds/winpe-final.vhd" -VmNamePrefix "IMG-MAG-test" -vmSize 'Standard_D2' -DomNamePrefix "winpe-test" `
        -adminUsername "adminuser" -adminPassword "P@ssw0rd01" -TargetDiskParent "vhds/" -VnetSubnet "10.0.0.0/16" `
        -VnetSubnetConfig "10.0.0.0/24" -MAG
#>
param(
    [Parameter(Mandatory=$true)]
    $SubscriptionId,

    [Parameter(Mandatory=$true)]
    $StorageAccountName,

    [Parameter(Mandatory=$true)]
    $VhdPath,

    [Parameter(Mandatory=$true)]
    $VmNamePrefix,

    [Parameter(Mandatory=$true)]
    $vmSize,

    [Parameter(Mandatory=$true)]
    [ValidatePattern("^[a-z][a-z0-9-]{1,61}[a-z0-9]$")]
    $DomNamePrefix,

    [Parameter(Mandatory=$true)]
    $AdminUsername,

    [Parameter(Mandatory=$true)]
    $AdminPassword,

    [Parameter(Mandatory=$true)]
    $TargetDiskParent,

    $VnetSubnet,

    $VnetSubnetConfig,

    [switch]$MAG
)

#region Authenticate
#Gather credentials for logging into the portal and adding MAG environment if necessary
if ($MAG)
{
    $creds = Get-Credential
    $login = Login-AzureRmAccount -Credential $creds
    while (! $login)
    {
        Write-Output "Could not login correctly, please try again."
        $login = Login-AzureRmAccount
    }
    #Add the MAG environment if the MAG switch is present
    Add-AzureRmAccount -EnvironmentName AzureUSGovernment -Credential $creds
}

#Otherwise, login normally
$login = Login-AzureRmAccount
while (! $login)
{
    Write-Output "Could not login correctly, please try again."
    $login = Login-AzureRmAccount
}

Select-AzureRmSubscription -SubscriptionId $SubscriptionId
$storageAccount = Get-AzureRmStorageAccount | Where-Object StorageAccountName -EQ $StorageAccountName
if (! $StorageAccountName)
{
    throw "Could not find storage account."
}
$resourceGroupName = $storageAccount.ResourceGroupName
$location = $storageAccount.Location
#endregion

#region VM name and size
#Generate a random two integer id at the end of the VM name
$i=1
$vmName = "$VmNamePrefix$($i.tostring("00"))"
while (Get-AzureRmVM -ResourceGroupName $resourceGroupName -name $vmName -ErrorAction Ignore)
{
    $i++
    $vmName = "$VmNamePrefix$($i.tostring("00"))"
}
Write-Output $vmName
#endregion

#region Networking
$nicName = "$vmName-NIC"
$ipName = "$vmName-IP"
#DNS Label must conform to this regex: ^[a-z][a-z0-9-]{1,61}[a-z0-9]$
$domName = "$DomNamePrefix-$($i.tostring("00"))"

$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -ErrorAction Ignore
if (!$vnet)
{
    $vnetName = "$vmName-vNet"
    $vnetDef = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $vnetName -AddressPrefix $VnetSubnet
    $vnet = $vnetDef | Add-AzureRmVirtualNetworkSubnetConfig -Name 'Subnet-1' -AddressPrefix $VnetSubnetConfig | Set-AzureRmVirtualNetwork
}

$securityGroupRule = New-AzureRmNetworkSecurityRuleConfig -Name Allow-RDP -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$securityGroup = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name "$vmname-NSG" -SecurityRules $securityGroupRule -Force
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $ipName -DomainNameLabel $domName -AllocationMethod Dynamic -Force
$nic = New-AzureRmNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name $nicName -PublicIpAddressId $pip.Id -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $securityGroup.Id -Force
#endregion

#region Create the VM Config using the variables configured above
$vm = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize

#Create admin credentials; $adminUsername cannot be "administrator"
$cred = New-Object PSCredential $adminUsername, ($adminPassword | ConvertTo-SecureString -AsPlainText -Force)

$vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id

#Attach the disk and reference an uploaded image ($sourceImageUri)
$sourceImageUri = "$($storageAccount.PrimaryEndpoints.Blob.ToString())$VhdPath"
$osDiskUri = "$($storageAccount.PrimaryEndpoints.Blob.ToString())$TargetDiskParent$vmName-OsDisk.vhd"
$vm = Set-AzureRmVMOSDisk -VM $vm -Name "$vmName-OSDisk" -VhdUri $osDiskUri -CreateOption FromImage -SourceImageUri $sourceImageUri -Windows

#Create the VM using the config
New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $location -VM $vm
#endregion
