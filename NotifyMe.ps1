$Outlook = New-Object -ComObject Outlook.Application
$Mail = $Outlook.CreateItem(0)
#Props
$Mail.To = "Faraz.Poomun@xxx.com"
$Mail.Subject = "Execution Done"
$Mail.Body = "Time to work!"
#send message
$Mail.Send()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($Outlook) | Out-Null