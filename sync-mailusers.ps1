<#
.SYNOPSIS
    This script creates mail contacts in target tenant for each mailbox in source tenant.

.DESCRIPTION
    This script creates mail contacts in target tenant for each mailbox in source tenant.

.NOTES
    Requires Windows Azure Active Directory Module for Windows PowerShell to be installed on PC.
    Change Log
        1.0 - 

    Sync-MailUsers.ps1
    v1.0
    12/16/2016
    By Jeff Gulliet, MVP|MCSM + Nathan O'Bryan, MVP|MCSM

.LINK
    

.EXAMPLE

#>

#Check for Azure AD PowerShell module
If (-not(Get-Module -ListAvailable -Name MSOnline)) {
    Write-Host "Azure AD Module is not installed on this machine"
    Write-Host "Please install it before running this script"
    Write-Host "Ending script"

    Exit
}

#The following two lines will create encrypted XML files that contain the source and target tenant admin credentials used throughout the script
#New-Object System.Management.Automation.PSCredential("admin@contoso.com", (ConvertTo-SecureString -AsPlainText -Force "P@ssword")) | Export-CliXml "C:\Temp\SourceCredential.xml"
#New-Object System.Management.Automation.PSCredential("admin@fabrikam.com", (ConvertTo-SecureString -AsPlainText -Force "P@ssword")) | Export-CliXml "C:\Temp\TargetCredential.xml"

#Edit $TargetDomain to use the target tenant's domain
$TargetDomain = "@niousa.onmicrosoft.com"

#Connect to ExO in the source tenant using the 'source' prefix
Write-Host 'Enter source tenant credentials'
$SourceCred = Get-Credential
$SourceSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://partner.outlook.cn/powershell -Credential $SourceCred -Authentication Basic -AllowRedirection
Import-PSSession $SourceSession -WarningAction SilentlyContinue -Prefix source
Clear-Host

#Connect to ExO in the target tenant using the 'target' prefix
Write-Host 'Enter target tenant credentials'
$TargetCred = Get-Credential
$TargetSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $TargetCred -Authentication Basic -AllowRedirection
Import-PSSession $TargetSession -WarningAction SilentlyContinue -Prefix target
Clear-Host

#Get all the source mailboxes in the source tenant
Write-Host "Reading Mailboxes from Source Tenant"
$sourceMBXs = Get-sourceMailbox -ResultSize unlimited -RecipientTypeDetails UserMailbox
$NumUsers = $sourceMBXs.count
$i = 0
Clear-Host

#Connect to MSOL in the target tenant
Connect-MsolService -Credential $TargetCred

foreach ($user in $SourceMBXs) {

    #Show progress counter
    $i++
    Write-Progress -Activity “Updating Mail Contacts in $TargetDomain” -Status “User $i of $NumUsers” -PercentComplete ($i/$NumUsers*100)
        
    #Test for existing mailbox and create/update mail contact if not present
    If (([bool](Get-targetMailbox $Name -ErrorAction SilentlyContinue) -Eq $False) -And ([bool](Get-targetMailUser $Name -ErrorAction SilentlyContinue) -Eq $False) ) {

        #Setup attributes for new mail user
	    $UPN = [string]$user.Alias + $TargetDomain
        $ADUser = Get-MsolUser -UserPrincipalName $user.UserPrincipalName
	    $Name = $user.Name
	    $FirstName = $ADUser.FirstName
	    $LastName = $ADUser.LastName
	    $Email = $user.WindowsEmailAddress
	    $City = $ADUser.City
	    $Country = $ADUser.Country
	    $Department = $ADUser.Department
	    $Fax = $ADUser.Fax
	    $MobilePhone = $ADUser.MobilePhone
	    $Office = $ADUser.Office
	    $PhoneNumber = $ADUser.PhoneNumber
	    $PostalCode = $ADUser.PostalCode
	    $State = $ADUser.State
	    $StreetAddress = $ADUser.StreetAddress
	    $Title = $ADUser.Title
        
        #Create MailUser	
        Write-Host "Creating Mail User: $Email"
        New-targetMailUser -Name $Name -FirstName $FirstName -LastName $LastName -ExternalEmailAddress $Email -MicrosoftOnlineServicesID $UPN -Password (ConvertTo-SecureString -String 'P@ssw0rd1' -AsPlainText -Force) -ErrorAction SilentlyContinue
        do {$NewMsolUser = Get-MsolUser -UserPrincipalName $UPN -ErrorAction SilentlyContinue} until ($NewMsolUser -ne $null)
	    Set-MsolUser -UserPrincipalName $UPN -City $City -Country $Country -Department $Department -Fax $Fax -MobilePhone $MobilePhone -Office $Office -PhoneNumber $PhoneNumber -PostalCode $PostalCode -State $State -StreetAddress $StreetAddress -Title $Title -ErrorAction SilentlyContinue
	}
    
    Else {}
}