# Define Env Variable
$statusVault = "primary"	# valid value: primary | standby. Vault = primary & DR = standby
$vaultIP = "vault.company.local"

# SMTP email configuration
$smtpServer = "mail.company.local"		# Replace with your SMTP server address
$smtpPort = 25							# Replace with your SMTP server port (e.g., 587 for TLS)
$fromEmail = "monitoring@company.local"	# Replace with your sender email address
$toEmail = "admin@company.local"			# Replace with the recipient's email address
#$smtpUsername = "sender@mylab.local"	# Replace with your SMTP username
#$smtpPassword = "This=S3cr3T"				# Replace with your SMTP password
$codeStatus = "Critical"

# Define the ENE, PADR, and Vault commands
$vaultStatus = "status vault"
$eneStatus = "status ene"
$padrStatus = "status padr"

$logFile = "${vaultIP}.log"

# Function to run a command and check for "stopped" in the output
function CheckStatus {
    param(
        [string]$command
    )

    $output = & .\PARClient.exe $vaultIP /usepassfile .\pass /c $command
    $output = $output -split "`r`n" | Where-Object { $_ -match '\S' }
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$outputWithTimestamp = $timestamp + " - " + $output
		#DEBUG
		#Add-Content -Path $logFile -Value "DEBUG - $outputWithTimestamp"
	
    if ($output -match "stopped") {
		$outputWithTimestamp | Out-File -Append -FilePath $logFile 
		#Write-host "Send email to admin@lab.local with subject Service $output"
		try {
			$logMessage = $timestamp + " - [INFO] Sending email subject service $output to $toEmail"
			Add-Content -Path $logFile -Value $logMessage
			$bodyEmail = @"
	Dear Admin

	The service $output
	Please check service on server $vaultIP, and take necessary action.

	CyberArk Monitoring
	
	*This is an automated message*
"@
			Send-MailMessage -From $fromEmail -To $toEmail -Subject "[$codeStatus] Service $output" -Body $bodyEmail -SmtpServer $smtpServer -Port $smtpPort -ErrorAction Stop 2>> $logFile 
			#Send-MailMessage -From $fromEmail -To $toEmail -Subject "Service $output" -Body $bodyEmail -SmtpServer $smtpServer -Port $smtpPort -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, (ConvertTo-SecureString $smtpPassword -AsPlainText -Force)) -ErrorAction Stop 2>> $logFile 
		}
		catch { 
			$errorMessage = $_.Exception.Message
			$logMessage = $timestamp + " - [ERROR] Sending email failed: $errorMessage"
			Add-Content -Path $logFile -Value $logMessage 
			#Write-Host $logMessage
		}
    }
	elseif ($output -match "ITACM002S") {
		$outputWithTimestamp | Out-File -Append -FilePath $logFile 
	}
	elseif ($output -match "PARCL001S") {
		$outputWithTimestamp | Out-File -Append -FilePath $logFile 
	}
}

## RunAndLogCommand
if ($statusVault -match "primary"){
	CheckStatus -command $eneStatus
	CheckStatus -command $vaultStatus
}
else { 
	CheckStatus -command $padrStatus
}
