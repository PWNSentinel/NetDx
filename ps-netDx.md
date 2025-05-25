# PowerShell Network Diagnostic & Alerting Script (Enterprise Ready)

This document outlines the creation and deployment of a **PowerShell-based enterprise network diagnostic and self-healing script**. It performs adapter and IP checks, logs results, attempts recovery, and notifies via email and Microsoft Teams if issues persist. This guide is ideal for Security or Infrastructure Operations teams.

---

##  Overview

This solution includes:

*  Network diagnostics and auto-recovery
*  Logging to timestamped `.log` file on desktop
*  Eail alerts upon persistent network failure
*  Microsoft Teams notifications to a specified channel
*  Automated execution via Task Scheduler

> **⚠️ Location Services Note:** On **Windows**, Wi-Fi discovery depends on **location services** being enabled. Without it, the system may not list available Wi-Fi networks via `netsh wlan show networks`.

---

## 🧰 Main PowerShell Diagnostic (Dx) Script
Below is the main script framework. This diagnostic checks the status of network interfaces, IP configuration, WiFi profiles, available SSIDs, and externail connectivity.
From here we'll build on the script to respond to failover, logs, scheduled dx and real time alerts.

```powershell
# Network Diagnostics Script
Write-Host "===== Network Adapter Status =====" -ForegroundColor Cyan
Get-NetAdapter | Format-Table -AutoSize

Write-Host "`n===== IP Address Configuration =====" -ForegroundColor Cyan
Get-NetIPConfiguration | Format-List

Write-Host "`n===== Saved Wi-Fi Profiles =====" -ForegroundColor Cyan
netsh wlan show profiles

Write-Host "`n===== Available Wi-Fi Networks (SSID Scan) =====" -ForegroundColor Cyan
netsh wlan show networks mode=bssid

Write-Host "`n===== DNS Resolution & Internet Connectivity Test =====" -ForegroundColor Cyan
try {
    $pingResult = Test-Connection -ComputerName "google.com" -Count 4 -ErrorAction Stop
    $pingResult | Format-Table Address, ResponseTime, StatusCode -AutoSize
} catch {
    Write-Host "Ping test failed. Check DNS or Internet connectivity." -ForegroundColor Red
}
```
Be sure to execute the script as administrator.

**The comprehensive script will check:**

* Network adapter status
* IP address configuration
* Saved and available Wi-Fi profiles
* Ping to an external endpoint (Google)

If the ping fails:

* The script restarts the Wi-Fi adapter
* Releases and renews the IP address
* Logs all output
* If still offline, triggers email and Teams alerts

---

## 🧾 Logging Script Explained

Logs are saved to the Desktop as:

```
NetworkDiag_Complete_YYYYMMDD_HHMMSS.log
```

### Key Logging Components

```powershell
Function Log {
    param([string]$msg)
    $logLine = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $logFile -Value $logLine
}

Function Log-Command {
    param([string]$description, [scriptblock]$cmd)
    Log "===== $description ====="
    try {
        $result = & $cmd | Out-String
        Add-Content -Path $logFile -Value $result
    } catch {
        Log "Failed: $description - $_"
    }
}
```

These functions ensure reliable, readable, timestamped output.

---

## 📧 Email Alert Script

If the network remains unreachable after the automated repair, the script emails a detailed report.

### 🔁 Replace the following placeholders:

```text
smtp.domain.com        → smtp.office365.com OR smtp.gmail.com
alert@domain.com       → the sender email address
your_email@domain.com  → recipient's email address
```

### 📧 Email Configuration Block

```powershell
$emailFrom = "alert@domain.com"
$emailTo = "admin_email@domain.com"
$smtpServer = "smtp.office365.com"  # or Gmail

Send-MailMessage -From $emailFrom -To $emailTo -Subject "Network Alert" -Body $body -SmtpServer $smtpServer
```

> ⚠️ For **Gmail**, create an **App Password** and use `-Credential (Get-Credential)`.

---

## ⏲️ Task Scheduler Setup

### ✅ Steps to Automate the Script

1. Open **Task Scheduler**
2. Click **Create Task**
3. On the **General** tab:

   * Check **Run with highest privileges**
   * Select **Run whether user is logged on or not**
4. Under **Triggers**:

   * Click **New\...**
   * Select **Daily** or **Repeat every 15 minutes**
5. Under **Actions**:

   * Program/script:

     ```powershell
     C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
     ```
   * Add arguments:

     ```powershell
     -ExecutionPolicy Bypass -File "C:\Path\To\NetworkSelfHeal_Complete.ps1"
     ```
6. Click **OK** and enter admin credentials if prompted.

---

##  Microsoft Teams Alert Setup

### Step-by-Step

1. Open **Microsoft Teams**
2. Go to your **channel** (e.g., `#network-alerts`)
3. Click `...` next to the channel > **Connectors**
4. Add **Incoming Webhook**
5. Name it (e.g., `Network Bot`) and click **Create**
6. Copy the generated **Webhook URL**

### 🔧 Teams Alert Function

```powershell
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

    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType 'application/json'
}
```

### Example Call in Script

```powershell
$teamsWebhook = "https://outlook.office.com/webhook/your-url"
Send-TeamsAlert -webhookUrl $teamsWebhook -title "Network Failure" -message "Repair failed on $env:COMPUTERNAME"
```

---

## Summary

This script provides your SecOps or IT team with:

* Proactive diagnostics
* Automated remediation
* Audit logs
* Real-time alerting to email and Teams
* Easy integration into Windows Task Scheduler
* Can be sent to SEIM- forewardable logs for incident correlation

> Ready for use in remote worker support, zero-trust environments, or as part of blue team automation. For scaling to server fleets, consider integrating with centralized logging and SIEM solutions.

---
Integration with **Syslog**, **ELK**, **Splunk**, or a **Teams Adaptive Card** interface is possible. Make to have your HEC-Token (Splunk), or API keys. Syslog can handle direct forwarding (over port 514). 

---

**Developed for: PWNS Blue Team Automation**

PWNS approach for MS environments:

* Deployment via Microsoft Endpoint Security (Intune + Defender for Endpoint)> Attack Surface Reduction rules

* Schedule run with a registry-based scheduled task via GPO

* Combine with Azure Sentinel for SIEM correlation

If self managing and using PWNS approach, make sure to omit credentials and interactive prompts (Get-...) and execute silent logging. You want to avoid GUI dependencies so silent logging can work.

Always monitor. 


