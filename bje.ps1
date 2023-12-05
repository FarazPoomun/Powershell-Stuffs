param($version,[int]$count = 1,[int]$from = 1,[switch]$reset, [Switch]$InvokedFromScript)

$params = @{InvokedFromScript=$InvokedFromScript}
if ($version)
{
  $params.version = $version
}
. setenv.ps1 @params

if ($reset)
{
  $db = $dc[$version].ControlDBs[0]
  $props = Get-DBEntryData $db $version $dc
  echo $props.d
  &$dc.SqlCmd -S $props.s -U $props.u -P $props.p -d $props.d -h -1 -W -Q "SET QUOTED_IDENTIFIER ON;DELETE FROM BackgroundJobService" -b
}

if ($count -gt 30)
{
  "$count is too large. Using 30 instead."
  $count = 30
}

$bje = "$($dc[$version].BaseDir)\bin\_PublishedApplications\BJE\Quartz.Server.exe"
if ($from -eq 1)
{
  if ($count -gt 1)
  {
    2..$count |% {
      start cmd "/k",$bje,"-n","MyBJE$_","-w"
    }
  }
  if ($count -gt 0)
  {
    start cmd "/k",$bje
  }
}
else
{
  $from..($from + $count - 1) |% {
    start cmd "/k",$bje,"-n","MyBJE$_","-w"
  }
}