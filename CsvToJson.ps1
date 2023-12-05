clear

function toISO8601 ($dateStr)
{
    try
    {
        $dt=[DateTime]::Parse($dateStr)
        if ($dt.Kind -eq [DateTimeKind]::Unspecified)
        {            
            $dt=[DateTime]::Parse((Get-Date $dt -Format s) + "-05:00")
        }

        if ($etz.IsAmbiguousTime([DateTime]::Parse($dateStr)))
        {
            return (Get-Date $dt.ToUniversalTime() -Format s) + '.000Z'
        }
        else
        {
            return $dateStr
        }
    }
    catch
    {
        return $dateStr
    }
}

function printChange ($oldTstmp, $newTstmp, $propertyName)
{
    if ($oldTstmp -ne $newTstmp)
    {
        Write-Host -NoNewline -ForegroundColor Green  "    -> Changed"
        Write-Host -NoNewline -ForegroundColor Green ": ["
        Write-Host -NoNewline -ForegroundColor Red $tmpTstmp
        Write-Host -NoNewline -ForegroundColor Green "] to ["
        Write-Host -NoNewline -ForegroundColor Red $newTstmp
        Write-Host -NoNewline -ForegroundColor Green "] -> "
        Write-Host -ForegroundColor White $propertyName
    }
}

$etz=[System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
$timeFiles=("ExpectedPaySummaries.csv", "REEmployeePunchTransaction.csv", "REPaySummaryWFMReverseMappingData.csv")
Write-Host -ForegroundColor White " -> Parsing:" (pwd)

foreach ($csvFile in $(ls *.csv))
{
    Write-Host -ForegroundColor DarkGreen "  -> Converting:" ($csvFile.Name)
    $tmpCsvContent = Get-Content $csvFile.Name | ConvertFrom-Csv

    if ($timeFiles.Contains($csvFile.Name))
    {
        Write-Host -ForegroundColor DarkYellow "   -> Checking Timestamps:"

        foreach ($item in $tmpCsvContent)
        {
            if ($item.TimeStart)
            {
                $tmpTstmp=$item.TimeStart
                $item.TimeStart = toISO8601 $item.TimeStart
                printChange $tmpTstmp $item.TimeStart "TimeStart"
            }

            if ($item.TimeEnd)
            {
                $tmpTstmp=$item.TimeEnd
                $item.TimeEnd = toISO8601 $item.TimeEnd
                printChange $tmpTstmp $item.TimeEnd "TimeEnd"
            }

            if ($item.TimeStartRaw)
            {
                $tmpTstmp=$item.TimeStartRaw
                $item.TimeStartRaw = toISO8601 $item.TimeStartRaw
                printChange $tmpTstmp $item.TimeStartRaw "TimeStartRaw"
            }

            if ($item.TimeEndRaw)
            {
                $tmpTstmp=$item.TimeEndRaw
                $item.TimeEndRaw = toISO8601 $item.TimeEndRaw
                printChange $tmpTstmp $item.TimeEndRaw "TimeEndRaw"
            }
        }
    }
    
    ($tmpCsvContent | ConvertTo-Json) `
    -replace ': +"([-\+]{0,1}[0-9.]+)"', ': $1' `
    -replace ': +"(T|t)(R|r)(U|u)(E|e)"', ': true' `
    -replace ': +"(F|f)(A|a)(L|l)(S|s)(E|e)"', ': false' `
    -replace ': +null', ': ""' `
    -replace '": +', '": ' `
    | Out-File -FilePath $($csvFile.FullName).Replace(".csv",".json") -Force -Encoding ascii
}

popd
