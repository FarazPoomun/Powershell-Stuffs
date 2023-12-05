param($version, [Switch]$NoEnvValidate, [Switch]$DF2 = $false,[Switch]$ReadOnly = $false,
        [ValidateSet("http","https")]
		[string]
		$Protocol,
		[switch]$Elevated
)

if(!$Protocol){
	#Probably have a more elegant way to set default
	$Protocol = "http"
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
		ECHO "tried to elevate, did not work, aborting. Try invoking in Admin mode manually."
    } 
	else {
		ECHO "Attempting to elevate"

		$paramsSet = " -Protocol $($Protocol) ";

		if ($version)
		{
		$paramsSet += " -version $($version)";
		}
		
		if($DF2){
		$paramsSet += " -DF2 "
		}

		if($ReadOnly){
		$paramsSet += " -ReadOnly "
		}

        Start-Process powershell.exe -Verb RunAs -ArgumentList (' -noexit "{0}" "{1}" -elevated' -f $MyInvocation.MyCommand.Name, $paramsSet)
    }
}
else
{
	$params=@{InvokedFromScript=$true;NoEnvValidate=$NoEnvValidate}
	if ($version)
	{
	  $params.version=$version
	}
	. setenv @params
	Import-Module WebAdministration 2> $null

	if(!$ReadOnly){

		else
		{
			set-itemproperty iis:\sites\xx -name physicalpath -value "$($dcv.BaseDir)bin\_PublishedWebsites\xx"
			ECHO "Switching to WorkTree (2) $($dcv.BaseDir)"
		}
	}
	else {

		
	   ECHO "MyDayforce  - $($_df1 | select -exp PhysicalPath)"
	   ECHO "MyDayforce2 - $($_df2 | select -exp PhysicalPath)"
	}

		Get-WebBinding -port 51000 | Remove-WebBinding
		New-WebBinding -Name "MyDayforce" -IPAddress "*" -Port 51000 -Protocol $Protocol
		
		if($Protocol -eq "https"){
			ECHO "Setting to SSL"
			(Get-WebBinding -Port 51000).AddSslCertificate("71c4e9dd7db65e067e05554ad80bb8259c0207c4", "my")
		}	
}