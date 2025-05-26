# Author: Pwnsentinel
# Date: 2025-20-03
# === Full Enterprise Network Self-Heal with Logging, Email, and Teams Alerts ===


$wifiAdapter = "Wi-Fi"
$hostname = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$logFile = "$env:USERPROFILE\Desktop\NetworkDiag_Complete_$($timestamp -replace '[: ]','_').log"

# Email Configuration
$emailFrom = "alert@example.com"
$emailTo = "recipient@example.com"
$smtpServer = "smtp.example.com"

# Teams Webhook
$teamsWebhook = "https://outlook.office.com/webhook/your-webhook-url"

# Logging Utilities
$output = @()

Function Log {
    param([string]$msg)
    $logLine = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    $output += $logLine
    Add-Content -Path $logFile -Value $logLine
}

Function Log-Section {
    param([string]$title)
    Log "`n===== $title ====="
}

Function Log-Command {
    param([string]$description, [scriptblock]$cmd)
    Log-Section $description
    try {
        $result = & $cmd | Out-String
        $output += $result
        Add-Content -Path $logFile -Value $result
    } catch {
        Log "⚠️ Failed to run: $description - $_"
    }
}

Function Send-TeamsAlert {
    param (
        [string]$webhookUrl,
        [string]$title,
        [string]$message
    )
    $payload = @{
        "@type"    = "MessageCard"
        "@context" = "http://schema.org/extensions"
        "summary"  = $title
        "themeColor" = "FF0000"
        "title"    = $title
        "text"     = $message
    } | ConvertTo-Json -Depth 10

    try {
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType 'application/json'
        Log "✅ Teams alert sent."
    } catch {
        Log "❌ Failed to send Teams alert: $_"
    }
}

Function Send-EmailAlert {
    $subject = "🚨 Network Alert from $hostname"
    $body = $output -join "`n"
    try {
        Send-MailMessage -From $emailFrom -To $emailTo -Subject $subject -Body $body -SmtpServer $smtpServer
        Log "✅ Email alert sent to $emailTo"
    } catch {
        Log "❌ Failed to send email: $_"
    }
}

# Begin Diagnostics
Log "===== Starting Network Diagnostic Run on $hostname ====="

Log-Command "Adapter Status" { Get-NetAdapter | Format-Table -AutoSize }
Log-Command "IP Configuration" { Get-NetIPConfiguration }
Log-Command "Saved Wi-Fi Profiles" { netsh wlan show profiles }
Log-Command "Available Wi-Fi Networks" { netsh wlan show networks mode=bssid }

# Initial Ping
Log-Section "Initial Ping Test"
$pingTest = Test-Connection -ComputerName "google.com" -Count 2 -Quiet
if ($pingTest) {
    Log "✅ Internet connectivity verified."
} else {
    Log "❌ Ping failed. Attempting network recovery..."

    try {
        Disable-NetAdapter -Name $wifiAdapter -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 5
        Enable-NetAdapter -Name $wifiAdapter -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 10
        Log "✅ Adapter restarted."
    } catch {
        Log "❌ Adapter restart failed: $_"
    }

    Log-Command "ipconfig /release" { ipconfig /release }
    Start-Sleep -Seconds 3
    Log-Command "ipconfig /renew" { ipconfig /renew }
    Start-Sleep -Seconds 10

    # Retry Ping
    Log-Section "Retry Ping Test"
    $pingRetry = Test-Connection -ComputerName "google.com" -Count 2 -Quiet
    if ($pingRetry) {
        Log "✅ Network restored after repair."
    } else {
        Log "❌ Network still unreachable. Triggering alerts..."

        $teamsTitle = "🚨 Network Failure on $hostname"
        $teamsMessage = @"
Ping failed and repair unsuccessful
- Time: $timestamp
- Host: $hostname
- Adapter: $wifiAdapter
- Status: ❌ No Internet

Please investigate.
"@
        Send-TeamsAlert -webhookUrl $teamsWebhook -title $teamsTitle -message $teamsMessage
        Send-EmailAlert
    }
}

Log "===== End of Diagnostic Run ====="
