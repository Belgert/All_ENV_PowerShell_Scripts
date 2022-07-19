## - Pulls local and cloud AD accounts with the following attributes:  
## - DisplayName, UserPrincipalName, LastLogin, Enabled, PasswordNeverExpires, LastPasswordChange, WhenCreated, UserType, AccountType, Description, Notes 
## - Need to have AzureADPreview to run this script. 

## - Selecting a folder to save to 
Write-Host "Please select a folder to save to." -ForegroundColor red 
Add-Type -AssemblyName System.Windows.Forms 
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog 
[void]$folderBrowser.ShowDialog() 
$save = $folderBrowser.SelectedPath 

## - Connecting to modules  
Connect-MsolService 
Connect-AzureAD  

## - Variables 
Write-Host "Obtaining a list of all users..." -ForegroundColor red 
$ADusers = Get-ADUser -Filter * -Properties * | select * 
$AADusers = Get-MsolUser -All | select * 
$data = @() 

## - Adding all AD User accounts to array 
Write-Host "Formatting Local AD Users output..." -ForegroundColor red 
ForEach ($ADuser in $ADusers) {  

    if ($ADuser.DisplayName -eq $null) { 
        $DN = $ADuser.Name
    }  
    else { 
        $DN = $ADuser.DisplayName 
    } 

    $data += [pscustomobject] @{ 
        DisplayName          = $DN 
        UserPrincipalName    = $ADuser.UserPrincipalName 
        Source               = "Local AD" 
        Enabled              = $ADuser.Enabled 
        WhenCreated          = $ADuser.WhenCreated 
        LastLogin            = $ADuser.LastLogonDate 
        PasswordNeverExpires = $ADuser.PasswordNeverExpires 
        LastPasswordChange   = $ADuser.PasswordLastSet 
        UserType             = " " 
        Description          = $ADuser.Description 
        Notes                = $ADuser.Info 
    }
} 

  

## - Adding all AAD User accounts to array 
Write-Host "Formatting AAD Users output..." -ForegroundColor red 
ForEach ($AADuser in $AADusers) { 

    $UPN = $AADuser.UserPrincipalName.ToLower() 
    $retry = 0 
    $error.clear() 

    Write-Host "Obtaining AAD last login time for $UPN..." -ForegroundColor red 
    $lastlogin = Get-AzureAdAuditSigninLogs -Top 1 -Filter "UserPrincipalName eq '$UPN'" | select -ExpandProperty CreatedDateTime 

    if ([string]$error -match "HttpStatusCode: 429") { 
        while ($error -and $retry -lt 10) { 
            Write-Host "Retrying AAD last login time for $UPN in 10 seconds..." -ForegroundColor red 
            $error.clear() 
            Start-Sleep -s 10 
            $lastlogin = Get-AzureAdAuditSigninLogs -Top 1 -Filter "UserPrincipalName eq '$UPN'" | select -ExpandProperty CreatedDateTime 
            $retry++ 
        }
    } 

    if ($error -and $retry -eq 9) { 
        Write-Host "Failed to obtain AAD last login time for $UPN..." -ForegroundColor red 
    } 

    if ($AADuser.ImmutableID -eq $null) { 
        $note = "Cloud Only"
    } 
    else { 
        $note = "Cloud Synced" 
    } 

    $data += [pscustomobject] @{ 
        DisplayName          = $AADuser.DisplayName 
        UserPrincipalName    = $AADuser.UserPrincipalName 
        Source               = "AAD" 
        Enabled              = " " 
        WhenCreated          = $AADuser.WhenCreated 
        LastLogin            = $lastlogin 
        PasswordNeverExpires = $AADuser.PasswordNeverExpires 
        LastPasswordChange   = $AADuser.LastPasswordChangeTimestamp  
        UserType             = $AADuser.UserType 
        Description          = " " 
        Notes                = $note 
    }
} 

## - Export Report 
$data | Export-CSV -Path "$save\All_ENV_AllUsers $((Get-Date -format MM-dd-yyyy).ToString()).csv" -NoTypeInformation 

## - Disconnect 
Disconnect-AzureAD 