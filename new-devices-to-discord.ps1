<#
Optimized PowerShell Network Device Logger
- Efficient parallel scanning with job throttling
- Error handling and robustness
- Device identification (hostname, vendor)
- Discord webhook integration for real-time alerts
- Well-commented for clarity

Requirements:
- PowerShell 5.1+
- OUI CSV file (e.g., oui.csv with columns: "MACPrefix,Vendor")
- Discord webhook URL (replace in config)
#>

# === CONFIGURATION ===
$Subnet          = "192.168.1"                       # Your subnet
$MaxThreads      = 10                                # Max concurrent jobs
$KnownDevicesCSV = "C:\Network\known_devices.csv"    # Known devices file
$OUIFile         = "C:\Network\oui.csv"              # OUI vendor database
$LogFile         = "C:\Network\new_devices.log"      # Log file
$DiscordWebhook  = "https://discord.com/api/webhooks/your_webhook_here" # Replace with your webhook

# === INITIALIZATION ===
# Ensure output directory exists
$dir = Split-Path $KnownDevicesCSV
if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }

# Import OUI database for vendor lookup
$OUI = @{}
if (Test-Path $OUIFile) {
    Import-Csv $OUIFile | ForEach-Object { $OUI[$_.MACPrefix.ToUpper()] = $_.Vendor }
}

# Load known devices
$KnownDevices = @{}
if (Test-Path $KnownDevicesCSV) {
    Import-Csv $KnownDevicesCSV | ForEach-Object { $KnownDevices[$_.MAC] = $_ }
}

# === FUNCTIONS ===

# Get vendor from MAC address using OUI database
function Get-Vendor {
    param($MAC)
    try {
        $prefix = ($MAC -replace "[:-]", "").Substring(0,6).ToUpper()
        return $OUI[$prefix] ? $OUI[$prefix] : "Unknown"
    } catch { return "Unknown" }
}

# Get hostname (tries DNS, then NetBIOS)
function Get-Hostname {
    param($IP)
    try {
        $dns = Resolve-DnsName -Name $IP -ErrorAction Stop
        return $dns.NameHost
    } catch {
        try {
            $nbt = nbtstat -A $IP 2>$null | Select-String "<20>" | ForEach-Object {
                ($_ -split '\s+')[1]
            }
            return $nbt ? $nbt : ""
        } catch { return "" }
    }
}

# Scan a single IP for presence, MAC, hostname, vendor
function Test-Device {
    param($IP)
    $ErrorActionPreference = "SilentlyContinue"
    try {
        if (Test-Connection -ComputerName $IP -Count 1 -Quiet -TimeoutSeconds 1) {
            # Wait for ARP cache to update
            Start-Sleep -Milliseconds 200
            $arp = arp -a $IP | Select-String $IP
            if ($arp) {
                $parts = $arp -split '\s+'
                if ($parts.Length -ge 2) {
                    $MAC = $parts[1].ToUpper()
                    $Hostname = Get-Hostname $IP
                    $Vendor = Get-Vendor $MAC
                    return [PSCustomObject]@{
                        IP        = $IP
                        MAC       = $MAC
                        Hostname  = $Hostname
                        Vendor    = $Vendor
                        Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                    }
                }
            }
        }
    } catch {
        # Log error for troubleshooting
        Add-Content $LogFile "Error scanning $IP: $_"
    }
    return $null
}

# Send a Discord webhook alert
function Send-DiscordAlert {
    param($Device)
    try {
        $Body = @{
            username = "Network Monitor"
            embeds   = @(@{
                title       = "New Device Detected"
                color       = 65280 # Green
                description = "A new device has joined the network."
                fields      = @(
                    @{name="IP Address"; value=$Device.IP; inline=$true},
                    @{name="MAC Address"; value=$Device.MAC; inline=$true},
                    @{name="Hostname"; value=($Device.Hostname -ne "" ? $Device.Hostname : "N/A"); inline=$true},
                    @{name="Vendor"; value=$Device.Vendor; inline=$true},
                    @{name="Timestamp"; value=$Device.Timestamp; inline=$true}
                )
            })
        } | ConvertTo-Json -Depth 4
        Invoke-RestMethod -Uri $DiscordWebhook -Method Post -Body $Body -ContentType 'application/json'
    } catch {
        Add-Content $LogFile "Error sending Discord alert: $_"
    }
}

# === MAIN SCAN LOGIC ===

$Jobs = @()
foreach ($i in 1..254) {
    $IP = "$Subnet.$i"
    # Throttle jobs for efficiency
    while (@($Jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $MaxThreads) {
        Start-Sleep -Milliseconds 200
        $Jobs = $Jobs | Where-Object { $_.State -ne 'Completed' }
    }
    $Jobs += Start-Job -ScriptBlock ${function:Test-Device} -ArgumentList $IP
}

# Collect results
$Results = @()
foreach ($Job in $Jobs) {
    try {
        $Job | Wait-Job
        $output = Receive-Job $Job
        if ($output) { $Results += $output }
    } catch {
        Add-Content $LogFile "Error receiving job result: $_"
    }
    Remove-Job $Job
}

# Process new devices
$NewDevices = @()
foreach ($Device in $Results) {
    if (-not $KnownDevices.ContainsKey($Device.MAC)) {
        $NewDevices += $Device
        # Log to file
        $logEntry = "$($Device.Timestamp),$($Device.IP),$($Device.MAC),$($Device.Hostname),$($Device.Vendor)"
        Add-Content $LogFile $logEntry
        # Add to known devices CSV
        $Device | Select-Object IP,MAC,Hostname,Vendor,Timestamp | Export-Csv $KnownDevicesCSV -Append -NoTypeInformation
        # Send Discord alert
        Send-DiscordAlert $Device
    }
}

# Optional: Output summary to screen
if ($NewDevices) {
    Write-Host "New devices detected:`n$($NewDevices | Format-Table | Out-String)"
} else {
    Write-Host "No new devices found."
}
