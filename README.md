Deploy AzureRM VM with Accessible Pre-boot Environment
======================================================

            

Have you ever wanted to boot to WinPE in Azure and select an MDT Task Sequence?  This script resource supports an automation framework to deploy an Azure VM using a previously-uploaded, WinPE-capable VHD as the reference OS Disk.


Using the Microsoft Deployment Toolkit (MDT), Windows Assessment and Deployment Kit (WADK) for Windows 10, Microsoft Diagnostics and Recovery Toolset (DaRT) 10, and Azure & Hyper-V PowerShell modules, an administrator can successfully configure a custom
 VHD image that will boot to WinPE in an Azure VM to allow for MDT deployment options selection while still in the pre-boot environment.  A VM deployed in Azure using this customized VHD allows for remote interaction with the WinPE console using DaRT to
 select deployment options.


This script requires the AzureRM module.  This script is a typical AzureRM VM generation script, but the VM storage definition is specific to part of a
[Cloud OSD process](https://blogs.technet.microsoft.com/heyscriptingguy/2017/02/09/cloud-operating-system-deployment-winpe-in-azure/).


 

 

 


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
