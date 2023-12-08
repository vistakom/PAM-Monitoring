# This script will get the number of sessions for a specific user logged on to a Windows Server 2019

# Define variables
$PSMConnectUser = "psmconnect"
$psmIdentity = $env:COMPUTERNAME

# Get the number of sessions for the user
$sessionCount = 0
$queryUserResult = query user | Select-String $PSMConnectUser

foreach ($line in $queryUserResult) {
    $sessionCount++
}

# Get the current date and time in the yyyy-MM-dd HHmmss format
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$monthly = Get-Date -Format "yyyy-MM"
# Generate log file with pattern: <hostname>_concurrent_session_<yyyy>-<mm>.log
$logFile = "${psmIdentity}_concurrent_session_${monthly}.log"

# Write the result to the file
$lineToWrite = "$timestamp,$PSMConnectUser,$sessionCount"
$lineToWrite | Out-File -Append -FilePath $logFile

#Write-Host "Result written to $logFile"
#Write-Host $lineToWrite
