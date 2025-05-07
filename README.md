PowerShell Network Device Logger
created by Patrick Elliott


Monitor your local network for new devices, identify them, and receive real-time alerts in Discord.
This script is efficient, robust, and provides detailed device information (IP, MAC, hostname, and vendor).

Features:

Efficient parallel scanning of your local subnet (with throttling to avoid network congestion)

Device identification: IP, MAC address, hostname (DNS/NetBIOS), and manufacturer (vendor)

Maintains a list of known devices and logs new arrivals with timestamps

Real-time Discord alerts via webhook

Robust error handling and detailed logging

Requirements
PowerShell 5.1 or later

Administrator privileges (for ARP access)

OUI CSV file for MAC vendor lookup (see OUI File below)

Discord webhook URL (see Discord Setup below)

Windows environment (tested on Windows 10/11)

Setup
1. Clone or Download the Script
Save the script as NetworkDeviceLogger.ps1.

2. Prepare Directory Structure
Create a directory for logs and data (e.g., C:\Network).

3. OUI File
Download a MAC address vendor list (OUI database) as a CSV file.
Format:

text
MACPrefix,Vendor
001A2B,Apple Inc.
001B63,Samsung Electronics
...
Place this file at C:\Network\oui.csv or update the $OUIFile path in the script.

4. Discord Setup
Create a webhook in your Discord channel (Discord docs).

Copy the webhook URL.

Paste it into the $DiscordWebhook variable in the script.

5. Configure Script Parameters
Modify these variables at the top of the script as needed:

powershell
$Subnet          = "192.168.1"                       # Your subnet
$MaxThreads      = 10                                # Max concurrent jobs
$KnownDevicesCSV = "C:\Network\known_devices.csv"    # Known devices file
$OUIFile         = "C:\Network\oui.csv"              # OUI vendor database
$LogFile         = "C:\Network\new_devices.log"      # Log file
$DiscordWebhook  = "https://discord.com/api/webhooks/your_webhook_here"
Usage
Run the script as Administrator:

powershell
powershell -ExecutionPolicy Bypass -File .\NetworkDeviceLogger.ps1
Automate:
Schedule the script to run at intervals using Windows Task Scheduler for continuous monitoring.

Output
New devices: Logged in C:\Network\new_devices.log and appended to known_devices.csv

Discord alert: New device details sent to your Discord channel

Errors: Logged in new_devices.log

Customization
Change subnet: Edit $Subnet (e.g., "192.168.0")

Adjust scan frequency: Use Task Scheduler to set interval

Change alert destination: Replace the Discord webhook with another service if needed

Troubleshooting
Missing vendor info: Ensure your OUI CSV file is up to date and in the correct format.

No Discord alerts: Double-check your webhook URL and Discord channel permissions.

Permission errors: Run PowerShell as Administrator.

Credits,

IEEE OUI Database

PowerShell community for parallel scanning techniques

Example Discord Alert
![Discord alert example](https://i.imguace with your own screenshot if desired -->


