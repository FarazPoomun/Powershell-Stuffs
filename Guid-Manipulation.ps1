<#
.SYNOPSIS
   1. Run command "notepad $PROFILE" in powershell to open profile file, if it dont exists, a new one will be prompted to be created
   2. Drop this file in the same location of your profile folder (Running Command "$PROFILE" will display location)
   3. Import this file in your profile class (e.g. Import-Module "C:\Users\fpoomun\OneDrive - Objectivity Sp. z o.o\Dokumenty\WindowsPowerShell\Guid-Manipulation.ps1";)
   4. Restart powershell for profile to take effect
   5. If you run into execution policy errors (try "Set-ExecutionPolicy RemoteSigned" or "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" or google it ;))
#>

Function Convert-GuidToBase64 { 
    [CmdletBinding()] 
    Param( 
            [Parameter(Position = 0, Mandatory = $true)][String]$Guid
    ) 
    $base64 = [system.convert]::ToBase64String(([GUID]$guid).ToByteArray())
    Set-Clipboard -Value $base64
    Write-Output $base64
}

Function Convert-Base64ToGuid { 
    [CmdletBinding()] 
    Param( 
            [Parameter(Position = 0, Mandatory = $true)][String]$base64
    ) 
    $guid = [GUID]([system.convert]::FromBase64String($base64))
    Set-Clipboard -Value $guid.ToString()
    Write-Output $guid.ToString()
}