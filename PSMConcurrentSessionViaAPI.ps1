## SET VARIABLE HERE ##
$src_pvwa_url = "https://pvwa.tell.me/passwordvault"

## SSL Skip Verify ##
#add-type @"
#    using System.Net;
#    using System.Security.Cryptography.X509Certificates;
#    public class TrustAllCertsPolicy : ICertificatePolicy {
#        public bool CheckValidationResult(
#            ServicePoint srvPoint, X509Certificate certificate,
#            WebRequest request, int certificateProblem) {
#            return true;
#        }
#    }
#"@
#[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

## FUNCTION ##
Function CheckDir {
	[CmdletBinding()]
	Param (
        [string[]]$Path
	)
	foreach ($p in $Path)
	{
		if ( -Not (Test-Path $p -PathType Container))
		{
			New-Item -Force -Path $p -ItemType Directory | Out-Null
		}
	}
}

Function Log {
    param(
        [Parameter(Mandatory=$false)][String]$msg
    )
    $datetime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	if ([string]::IsNullOrEmpty($msg)) {
            $msg = "N/A" 
        }
    Add-Content $LogFile $datetime' '$msg
}

## GENERATE variable log, result, time converter ##
$date = Get-Date -Format "yyyy-MM-dd"
$monthly = Get-Date -Format "yyyy-MM"
$dir = "" 
$session_filename = "PSM_concurrent_session_${monthly}.csv"

if ($dir -eq "")
    {
        $dir = $PSScriptRoot
    }
$result_dir = "$dir\Report"
$logs_dir = "$dir\Logs"
$LogFile = "$logs_dir\$(($MyInvocation.MyCommand.Name).Replace("ps1","log"))"
CheckDir -Path $result_dir, $logs_dir

## LOGIN PHASE ##
#Login SRC PAM
# Parse the XML to extract the encrypted string
[xml]$conf = Get-Content -Path "config.xml"

# Convert the encrypted standard string back to a secure string
$secureString1 = ConvertTo-SecureString -String $conf.ConfigFile.Param1
$secureString2 = ConvertTo-SecureString -String $conf.ConfigFile.Param2

# Convert the secure string to plain text
$username = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString1))
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString2))

$src_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$src_headers.Add("Content-Type", "application/json")
$src_logonBody = @{ username = $username; password = $password; concurrentSession = "true" }
$src_logonBody = $src_logonBody | ConvertTo-Json
try
{
    # Logon
    $src_pvwa_url_logon = "$src_pvwa_url/API/Auth/CyberArk/Logon"
    $src_logonToken = Invoke-RestMethod $src_pvwa_url_logon -Method 'POST' -Headers $src_headers -Body $src_logonBody
    #Write-Host "SRC Token: $src_logonToken"
}
catch [System.Net.WebException] {
	IF (![string]::IsNullOrEmpty($(($_.ErrorDetails.Message | ConvertFrom-Json).ErrorCode))) {
		$ErrorCode = ($_.ErrorDetails.Message | ConvertFrom-Json).ErrorCode
        $ErrorMessage = ($_.ErrorDetails.Message | ConvertFrom-Json).ErrorMessage
		Log "[ERROR] Login Failed - $ErrorCode : $ErrorMessage"
	} Else {
		$ErrorCode = $_.Exception.Response.StatusCode.value__
        $ErrorMessage = $_.Exception.Response.StatusDescription
		Log "[ERROR] Login Failed - $ErrorCode : $ErrorMessage"	   
	}
	$src_logonToken = ""
}
If ($src_logonToken -eq "")
{
    #Log "[ERROR] - Logon Token is Empty - Failed login SRC PVWA `n`n`n"
    Exit
}
$src_headers.Add("Authorization", $src_logonToken)

## GET LIST Active Session ##
$src_pvwa_url_session_list = "$src_pvwa_url/api/livesessions?limit=1000"
$response = Invoke-RestMethod $src_pvwa_url_session_list -Method "GET" -Headers $src_headers
$total = $response.Total
#Log "Number of active session(s): $total"

$active_session = $response | ForEach-Object {
    $_.LiveSessions | ForEach-Object {
        $businessEmail = $response1.internet.businessEmail
		[pscustomobject] @{
                'DateTime' = Get-Date
                'SessionID' = $_.SessionID
                'Duration' = $_.Duration
                'ConnectionComponentID' = $_.ConnectionComponentID
                'ProviderID' = $_.RawProperties.ProviderID
                'User'  = $_.User
                'AccountUsername' = $_.AccountUsername
                'AccountAddress' = $_.AccountAddress
			}
		}	
    }

# Save the custom objects to a CSV file
$active_session | Export-CSV $result_dir\$session_filename -NoTypeInformation -Append -Force

#################################
#Log "Logout"
$src_pvwa_url_logoff = "$src_pvwa_url/API/Auth/Logoff"
$logoff = Invoke-RestMethod $src_pvwa_url_logoff -Method 'POST' -Headers $src_headers
if (-Not $logoff) 
{ 
    Log "[ERROR] - Logout PVWA Failed"
}
Exit
