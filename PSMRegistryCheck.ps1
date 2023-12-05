# Define environment variables
$psmIdentity = $env:COMPUTERNAME
$registryThreshold = 50
$logFile = "${psmIdentity}_registry.log"

# smtp server
$smtpServer = "mail.company.local"
$smtpPort = 25
$fromEmail = "monitoring@company.local"
$toEmail = "admin@company.local"
$codeStatus = "Critical"

# registry path
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\VolatileNotifications"

$ipAddress = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString


# Define a function to send an email
function Send-Email($subject, $body) {
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "$timestamp - [INFO] Sending email to $toEmail with subject: $subject"
        Add-Content -Path $logFile -Value $logMessage
        Send-MailMessage -From $fromEmail -To $toEmail -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -ErrorAction Stop 2>> $logFile
    }
    catch {
        $errorMessage = $_.Exception.Message
        $logMessage = $timestamp + " - [ERROR] $errorMessage"
        Add-Content -Path $logFile -Value $logMessage
    }
}

# Main script logic
try {
    $registryKey = Get-Item -Path $registryPath -ErrorAction Stop
    $countKey = $registryKey.GetValueNames().Count

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $countKey"
    Add-Content -Path $logFile -Value $logMessage

    if ($countKey -gt $registryThreshold) {
        $bodyEmail = @"
        Dear Admin,

        Total entries '$registryPath' on $psmIdentity has exceeded the predefined threshold value.
		Detail:
		Current Value:	$countKey
		Treshold value:	$registryThreshold
		Server Address:	$psmIdentity ($ipAddress)
		
        Please take necessary action immediately or contact System Administrator.

        CyberArk Monitoring

        *This is an automated message*
"@
		$subjectEmail ="[$codeStatus] Number of Registry on $psmIdentity has exceeded"
        Send-Email -subject $subjectEmail -body $bodyEmail
    }
}
catch {
    $errorMessage = $_.Exception.Message
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - [ERROR] $errorMessage"
    Add-Content -Path $logFile -Value $logMessage
}
