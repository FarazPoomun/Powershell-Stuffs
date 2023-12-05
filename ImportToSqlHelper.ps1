#-6 - TIME
#-5 - GUID
#-4 - DATETIME
#-3 - bit
#-2 - integer
#-1 - float
#N - string of length N

function IsTime($value)
{
  $ts = New-Object "System.TimeSpan"
  [TimeSpan]::TryParse($value,[ref]$ts)
}
function IsDateTime($value)
{
  $dt = New-Object "System.DateTime"
  [DateTime]::TryParse($value,[ref]$dt)
}
function IsGuid($value)
{
  $g = New-Object "System.Guid"
  [Guid]::TryParse($value,[ref]$g)
}
function IsInteger($value)
{
  $value -match '^[+-]?[0-9]+\.?0*$'
}
function IsFloat($value)
{
  $value -match '^[+-]?[0-9]*\.[0-9]+$'
}
function IsBit($value)
{
  $value -eq "1" -or $value -eq "0" -or $value -eq "true" -or $value -eq "false"
}
function IsNull($value)
{
  $value -eq $null -or $value -eq "" -or $value -is [DBNull]
}

function GetSqlType([Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]$o)
{
  begin
  {
    $MaxLength = 0
    $TypeCode = -3
    $MaxInt = [long]::MinValue
    $MinInt = [long]::MaxValue
    $MaxFloat = [double]::MinValue
    $MinFloat = [double]::MaxValue
    $First = $true
  }
  process
  {
    $value = $o.PSObject.Properties.Value 
    if (!(IsNull $value))
    {
      if ($MaxLength -lt $value.Length)
      {
        $MaxLength = $value.Length
      }

      if (!$First -and (
            ($TypeCode -eq -4 -and !(IsDateTime $value)) -or 
            ($TypeCode -eq -5 -and !(IsGuid $value)) -or 
            ($TypeCode -eq -6 -and !(IsTime $value)))
            )
      {
        $TypeCode = $MaxLength
      }
      else
      {
        if ($TypeCode -eq -3 -and !(IsBit $value))
        {
          $TypeCode = -2
        }
        
        if ($TypeCode -eq -2)
        {
          if (IsInteger $value)
          {
            $x = [long]$value
            if ($MaxInt -lt $x)
            {
              $MaxInt = $x
            }
            if ($MinInt -gt $x)
            {
              $MinInt = $x
            }
          }
          else
          {
            $TypeCode = -1
          }
        }
        
        if ($TypeCode -eq -1)
        {
          if (IsFloat $value)
          {
            $x = [double]$value
            if ($MaxFloat -lt $x)
            {
              $MaxFloat = $x
            }
            if ($MinFloat -gt $x)
            {
              $MinFloat = $x
            }
          }
          elseif ($First)
          {
            $TypeCode = -6
          }
          else
          {
            $TypeCode = 0
          }
        }
        
        if ($TypeCode -eq -6 -and !(IsTime $value))
        {
          $TypeCode = -4
        }

        if ($TypeCode -eq -4 -and !(IsDateTime $value))
        {
          $TypeCode = -5
        }

        if ($TypeCode -eq -5 -and !(IsGuid $value))
        {
          $TypeCode = $MaxLength
        }

        if ($TypeCode -ge 0)
        {
          $TypeCode = $MaxLength
        }
      }
      
      $First = $False
    }
  }
  end
  {
    switch ($TypeCode)
    {
      0 { 'BIT' }
      -3 { 'BIT' }
      -2 {
        if ($MaxInt -le [int]::MaxValue -and $MinInt -ge [int]::MinValue)
        {
          'INT'
        }
        else
        {
          'BIGINT'
        }
      }
      -1 { 'FLOAT' }
      -4 { 'DATETIME' }
      -5 { 'UNIQUEIDENTIFIER' }
      -6 { 'TIME' }
      default { 
        if ($TypeCode -gt 4000)
        {
          "NVARCHAR(MAX)" 
        }
        else
        {
          "NVARCHAR($TypeCode)" 
        }
      }
    }
  }
}

function BuildCreateTableSql([string]$Table, [array]$Columns, [switch]$DropTarget)
{
  $Columns |% { 
    if ($DropTarget)
    {
      @"
IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = `'$Table`')
  DROP TABLE [$Table]
"@
    }
    "CREATE TABLE [$Table] ("
    $delim = ' ' 
  } { 
    " $delim[$($_.ColumnName)] $($_.SqlType)"
    $delim = ',' 
  } { 
    ")" 
  }
}