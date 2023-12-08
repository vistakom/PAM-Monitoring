# Define Env Variable
$vaultIP = "vault.mylab.local"

# Define the ENE, PADR, and Vault commands
$vaultCpu = "GetCPU"
$vaultMem = "GetMemoryUsage"
$vaultDisk = "GetDiskUsage"

# Function to run a command and check for resource usage
function GetUsage {
    param(
        [string]$command
    )

    $output0 = & .\PARClient.exe $vaultIP /usepassfile .\pass /c $command
    $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    $monthly = Get-Date -Format "yyyy-MM"
    $logFile = "${vaultIP}_${command}_${monthly}.csv"

    if ($command -eq $vaultCpu) {
        # Remove '%' symbol from CPU usage
        $output = $output0 -replace '%', ''
    }
    elseif ($command -eq $vaultMem) {
		
        $pattern = "Utilized=(\d+\.\d+)%"
        $match = [regex]::Match($output0, $pattern)
        $output = $match.Groups[1].Value
    }
    elseif ($command -eq $vaultDisk) {
        $pattern = "\((\d+\.\d+%)\)"
        $matches = [regex]::Matches($output0, $pattern)
        $usagesizes = @()
        foreach ($match in $matches) {
            $percentageWithPercent = $match.Groups[1].Value
            $freesize = $percentageWithPercent -replace '%', ''
            $usagesize = 100 - [decimal]$freesize 
            $usagesizes += $usagesize
        }
        $output = $($usagesizes -join ';')
    }
    else {
        $output = $output0 -join ' '
    }

	# convert array $output0 to string
	$source = $output0 -join ' '
    # Create a custom object with timestamp and output data
    $logEntry = [PSCustomObject]@{
        Tanggal = $timestamp
        'Usage (%)'= $output
		SourceData = $source  
    }

    # Export the log entry to a CSV file
    $logEntry | Export-Csv -Append -Path $logFile -NoTypeInformation
}

# Run the GetUsage function for each command
GetUsage -command $vaultCpu
GetUsage -command $vaultMem
GetUsage -command $vaultDisk
