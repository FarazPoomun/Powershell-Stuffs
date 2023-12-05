param($version,[Switch]$NoEnvValidate, [Parameter(Mandatory =$true)] $pattern )

$params=@{InvokedFromScript=$true;NoEnvValidate=$NoEnvValidate}
if ($version)
{
  $params.version=$version
}
. setenv @params

$baseDir = $dcv.BaseDir

select-string -path $("$($baseDir)DB\SQL\ClientDB\*.sql") -pattern $pattern
 