#Sync-MailUsers.ps1
#Jeff Guillet, MVP | MCSM

#Edit this line to use the target tenant's domain
$TargetDomain = "@fabrikam.com"

#The following two lines will create encrypted XML files that contain the source and target tenant admin credentials used throughout the script
#New-Object System.Management.Automation.PSCredential("admin@contoso.com", (ConvertTo-SecureString -AsPlainText -Force "P@ssword")) | Export-CliXml "C:\Temp\SourceCredential.xml"
#New-Object System.Management.Automation.PSCredential("admin@fabrikam.com", (ConvertTo-SecureString -AsPlainText -Force "P@ssword")) | Export-CliXml "C:\Temp\TargetCredential.xml"

#Connect to EXO in the source tenant using the 'source' prefix
$SourceCred = Import-Clixml -Path "C:\Temp\SourceCredential.xml"
$SourceSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $SourceCred -Authentication Basic -AllowRedirection
Import-PSSession $SourceSession -WarningAction SilentlyContinue -Prefix source

#Connect to EXO in the target tenant using the 'target' prefix
$TargetCred = Import-Clixml -Path "C:\Temp\TargetCredential.xml"
$TargetSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $TargetCred -Authentication Basic -AllowRedirection
Import-PSSession $TargetSession -WarningAction SilentlyContinue -Prefix target

#Get all the source mailboxes in the source tenant
$sourceMBXs = Get-sourceMailbox -ResultSize unlimited

foreach ($user in $SourceMBXs) {
	#Connect to MSOL in the source tenant
	Connect-MsolService -Credential $SourceCred

	#Generate the new target UPN
	$UPN = [string]$user.Alias + $TargetDomain

	#Create the new Mail User and update the MSOL user if it doesn't already exist
	if ([bool](Get-targetMailUser $UPN -ErrorAction SilentlyContinue) -eq $false) {
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

		Write-Host "Creating Mail User: $UPN"
		New-targetMailUser -Name $Name -FirstName $FirstName -LastName $LastName -ExternalEmailAddress $Email -MicrosoftOnlineServicesID $UPN -Password (ConvertTo-SecureString -String 'P@ssw0rd1' -AsPlainText -Force)

		Write-Host "Updating MsolUser:  $UPN"
		#Connect to MSOL in the target tenant
		Connect-MsolService -Credential $TargetCred

		#We can't actually update the MSOL user until it syncs back to AAD from EXODS
		do { $NewMsolUser = Get-MsolUser -UserPrincipalName $UPN -ErrorAction SilentlyContinue } until ($NewMsolUser -ne $null)
		Set-MsolUser -UserPrincipalName $UPN -City $City -Country $Country -Department $Department -Fax $Fax -MobilePhone $MobilePhone -Office $Office -PhoneNumber $PhoneNumber -PostalCode $PostalCode -State $State -StreetAddress $StreetAddress -Title $Title
	}
}
