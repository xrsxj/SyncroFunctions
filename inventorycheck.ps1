Write-Host "Script Version 3.2"

Import-Module $env:SyncroModule
$WarningPreference = 'SilentlyContinue'
$syncrodomain = "mydomainhere"

<# Required Custom Asset Fields for Syncro

"Crashplan Installed" - Check Box
"CloudBerry Installed" - Check Box
"Office Version" - Text Field
"Bitlocker Keys" - Text Area
"Memory FormFactor" - Text Field
"Memory Type" - Text Field
"Memory Slots (Total)" - Text Field
"Memory Slots (Filled)" - Text Field
"Product Keys" - Text Area
"Boot Drive Type" - Text Field
"Office Activated" - Check Box
"Windows Activated" - Check Box
"Bios Version" - Text Field
"PS Version" - Text Field
"Performance Index" - Text Area
"Office Keys" - Text Area
"Windows Key" - Text Area
"ZeroTier-NodeID" - Text Field
"Attached Screens" - Text Area
"Installed Choco Packages" - Text Area

#>

<# Required Script Variables

oscaption = asset_custom_field_os

#>

<# Required Script Files
You can get this from NirSoft for free
ProduKey.exe @ c:\Windows\Temp\ProduKey.exe

#>

# Save QB License Info
Write-Host "Checking for QB License"
if (Test-Path -Path "C:\ProgramData\COMMON FILES\INTUIT\QUICKBOOKS\qbregistration.dat") {
    Write-Host "QB License found... documenting"
    Rmm-Alert -Category 'record_qb' -Body 'Document QB License!'
}

# Check for Shares
Write-Host "Checking for File Shares"
if ((Get-SMBShare | Where-Object {$_.ShareType -eq "FileSystemDirectory" -and $km_.Special -eq $false}).count -ne 0) {
    Write-Host "File Shares found..... Documenting."
    Rmm-Alert -Category 'record_shares' -Body 'Document File Shares!'
}

# Check if DC
Write-Host "Check if DC..."
if ((Get-WmiObject -Class Win32_OperatingSystem).ProductType -eq 2) {
    Write-Host "DC FOUND!!!! Documenting"
    Rmm-Alert -Category 'record_ads' -Body 'Document ADS Information!'
}

# Set Architecture
$Arch = (Get-Process -Id $PID).StartInfo.EnvironmentVariables["PROCESSOR_ARCHITECTURE"];

if ($Arch -eq 'x86') {
    $arch = "x86"
}
elseif ($Arch -eq 'amd64') {
    $arch = "x64"
}

# Backup Software Check
if (Test-Path -Path "C:\Program Files\CrashPlan\electron\CrashPlanDesktop.exe") {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Crashplan Installed" -Value true
} else {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Crashplan Installed" -Value false
}
if (Test-Path -Path "C:\Program Files\CNS\Online Backup\cbb.exe") {
    Set-Asset-Field -Subdomain $syncrodomain -Name "CloudBerry Installed" -Value true    
} else {
    Set-Asset-Field -Subdomain $syncrodomain -Name "CloudBerry Installed" -Value false
}

# Software Inventory
Write-Host "Taking Software Inventory"
if ($Arch -eq 'x64') {
    $inventory = (Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
                HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty)
} 
else {
    $inventory = (Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty)
}

# Enable Windows Script Host
Write-Host "Enabling Windows Scripting Host"
New-ItemProperty -Force -Path "HKLM:\Software\Microsoft\Windows Script Host\Settings" -Name Enabled -PropertyType DWord -Value 1 | Out-Null

# Get BIOS Version
Write-Host "Checking BIOS/UEFI Version"
$bversion=$(Get-WmiObject -Class "Win32_Bios").SMBIOSBIOSVersion
Set-Asset-Field -Subdomain $syncrodomain -Name "Bios Version" -Value $bversion

# Bitlocker Check
Write-Host "Checking for bitlocker keys"
$fixeddrives = ([System.IO.DriveInfo]::GetDrives() | Where-Object{($_.DriveType -Match "Fixed") `
                -and (($_.DriveFormat -Match "NTFS") `
                -or ($_.DriveFormat -Match "ReFS"))}).Name
foreach ($fixeddrive in @($fixeddrives)) {
    $recoverypassword = (Get-BitLockerVolume -MountPoint $fixeddrive).KeyProtector.recoverypassword
    if ($recoverypassword) {
        $bitlockerkeys = $bitlockerkeys + "$fixeddrive   $recoverypassword `n"        
    }
    Set-Asset-Field -Subdomain $syncrodomain -Name "Bitlocker Keys" -Value $bitlockerkeys
}

# Check Boot Drive Type
Write-Host "Checking what type of drive the boot disk is, only works on Windows 10."
$drivetype = (Get-PhysicalDisk | Where-Object {$_.FriendlyName -eq ((Get-Disk | Where-Object {$_.IsBoot -eq 'True'}).FriendlyName)}).MediaType
if ($drivetype -like "Unspecified" -or $null -eq $drivetype) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Boot Drive Type" -Value "HDD"
}
else {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Boot Drive Type" -Value $drivetype
}

# Get Memory Info
Write-Host "Checking Memory Information"
$memdevices = 0
$memdevice = (Get-WmiObject Win32_PhysicalMemoryArray).MemoryDevices
$memdevice | ForEach-Object { $memdevices += $_} 
Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Slots (Total)" -Value $memdevices

$memcount = (Get-WmiObject Win32_PhysicalMemory).Count
if ($memcount) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Slots (Filled)" -Value $memcount
}
else {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Slots (Filled)" -Value "1"
} 


$memoryform = (Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1).FormFactor
if ($memoryform -eq 12) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory FormFactor" -Value "SO-DIMM"
}
elseif ($memoryform -eq 11) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory FormFactor" -Value "RIMM"
}
elseif ($memoryform -eq 8) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory FormFactor" -Value "DIMM"
}

else {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory FormFactor" -Value "UNK"
}
$memorytype = (Get-WmiObject Win32_PhysicalMemory | Select-Object -First 1).MemoryType

if ($memorytype -eq 20) {
Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "DDR"
}
elseif ($memorytype -eq 21) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "DDR2"
}
elseif ($memorytype -eq 22) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "DDR2 FB-DIMM"
}
elseif ($memorytype -eq 24) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "DDR3"
}
elseif ($memorytype -eq 0) {
    if (($oscaption -Match "10") -or ($oscaption -Match "2016") -or ($oscaption -Match "2019")) {
        Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "DDR4"
    }
    else {
        Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "UNK"
    }
}
elseif ($memorytype -eq 1) {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "Virtual"
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Slots (Filled)" -Value "Virtual"
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory FormFactor" -Value "Virtual"
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Slots (Total)" -Value "Virtual"
    exit 0
}
else {
    Set-Asset-Field -Subdomain $syncrodomain -Name "Memory Type" -Value "UNK"
}

# Office Activation and License Check

Write-Host "Checking if MS Office Installed"
$office = ($inventory | Where-Object {(($_.DisplayName -like "Microsoft Office*365*") `
            -or ($_.DisplayName -like "*Microsoft Office*20*") `
            -or ($_.DisplayName -like "*20*Microsoft Office*")) `
            -and ($_.SystemComponent -ne 1) `
			-and ($_.DisplayName -notmatch "Service") `
			-and ($_.DisplayName -notmatch "Components") `
			-and ($_.DisplayName -notmatch "Access") `
			-and ($_.DisplayName -notmatch "Security") `
			-and ($_.DisplayName -notmatch "Update") `
			-and ($_.DisplayName -notmatch "PDF") `
			-and ($_.DisplayName -notmatch "Interop" ) `
			-and ($_.DisplayName -notmatch "Meeting")}).DisplayName

Set-Asset-Field -Subdomain $syncrodomain -Name "Office Version" -Value ($office -replace " \- en\-us", "" -replace "Microsoft Office ", "" -replace " system", "")

if((($office -match '2013') `
    -or ($office -match '2016') `
    -or ($office -match '2019')) `
    -and ($office -notmatch 'Home')) {
    Write-Host "Checking Office License"
    if(Test-Path -Path "C:\Program Files (x86)\Microsoft Office\Office16\OSPP.VBS"){
        $wholeFile = (c:\Windows\System32\cscript.exe "C:\Program Files (x86)\Microsoft Office\Office16\OSPP.VBS" /dstatus)
    }
    elseif(Test-Path -Path "C:\Program Files\Microsoft Office\Office16\OSPP.VBS"){
        $wholeFile = (c:\Windows\System32\cscript.exe "C:\Program Files\Microsoft Office\Office16\OSPP.VBS" /dstatus)
    }
    elseif(Test-Path -Path "C:\Program Files (x86)\Microsoft Office\Office15\OSPP.VBS"){
        $wholeFile = (c:\Windows\System32\cscript.exe "C:\Program Files (x86)\Microsoft Office\Office15\OSPP.VBS" /dstatus)
    }
    elseif(Test-Path -Path "C:\Program Files\Microsoft Office\Office15\OSPP.VBS"){
        $wholeFile = (c:\Windows\System32\cscript.exe "C:\Program Files\Microsoft Office\Office15\OSPP.VBS" /dstatus)
    }
    if ($wholeFile) {
        if ($wholeFile -like "*-LICENSED-*"){
            Write-Host "Office License looks good!"
            Set-Asset-Field -Subdomain $syncrodomain -Name "Office Activated" -Value true
            Close-Rmm-Alert -Subdomain $syncrodomain -Category "office_activation_failed" -CloseAlertTicket "true" | Out-Null
        }
        else { 
            Write-Host "Office is not activated, or the check is failing to detect it"
            Set-Asset-Field -Subdomain $syncrodomain -Name "Office Activated" -Value false
            Rmm-Alert -Category 'office_activation_failed' -Body $wholeFile
        }
    }
    else {
        Write-Host "Looks like office is not activated, but i will not set an alert, it might be an old version"
        Set-Asset-Field -Subdomain $syncrodomain -Name "Office Activated" -Value false
    }
}
elseif ($office) {
    Write-Host "Looks like this MS Office is not one of ours"
    Set-Asset-Field -Subdomain $syncrodomain -Name "Office Provided" -Value false
    Set-Asset-Field -Subdomain $syncrodomain -Name "Office Activated" -Value true
}
else {
    Write-Host "Looks like no MS Office was detected"
    Set-Asset-Field -Subdomain $syncrodomain -Name "Office Provided" -Value false
    Set-Asset-Field -Subdomain $syncrodomain -Name "Office Activated" -Value false
}
    
#Check Windows Activation
$winlic = (c:\Windows\System32\cscript.exe "c:\windows\system32\slmgr.vbs" /dli)
if ($winlic -notmatch "Unlicensed"){
    Write-Host "Looks like Windows is activated with a good license."
    Set-Asset-Field -Subdomain $syncrodomain -Name "Windows Activated" -Value true
    Close-Rmm-Alert -Subdomain $syncrodomain -Category "windows_activation_failed" -CloseAlertTicket "true" | Out-Null
}
else {
    Write-Host "Looks like Windows is not activated setting alert."
    Set-Asset-Field -Subdomain $syncrodomain -Name "Windows Activated" -Value false
    Rmm-Alert -Category 'windows_activation_failed' -Body $winlic
    Log-Activity -Subdomain $syncrodomain -Message "Windows Activation Failed MESSAGE" -EventName "Windows Activation Failed EVENT"
}

# Check for Open Shell
$openshellinstalled = ($inventory | Where-Object {($_.DisplayName -like "*Open*Shell*")}).DisplayName

if ((!$openshellinstalled) `
    -and (($oscaption -match " 8") `
    -or ($oscaption -match " 10") `
    -or ($oscaption -match " 20"))) {
    Write-Host "Looks like Open-Shell is missing, setting alert!"
    Rmm-Alert -Category 'oshell_missing' -Body 'Missing Open Shell!'
}
elseif ($openshellinstalled) {
    Write-Host "Open-Shell found!, or not needed."
    Close-Rmm-Alert -Subdomain $syncrodomain -Category "oshell_missing" -CloseAlertTicket "true" | Out-Null
}

#Set NumLock on at Login
Write-Host "Setting NumLock on Login"
$path = 'Registry::\HKEY_USERS\.DEFAULT\Control Panel\Keyboard\'
$name = 'InitialKeyboardIndicators'
$value = '2'
Set-Itemproperty -Path $path -Name $name -Value $value

#Get Choco Packages
Write-Host "Documenting Choco packages"
[array]$packages = $null
$cpack = $(choco list -l -r --idonly) -split ' '
foreach ($cp in $cpack) {
    $packages += "$($cp.trim())`n"
}

Set-Asset-Field -Subdomain $syncrodomain -Name "Installed Choco Packages" -Value $($packages)

#Sync the Clocks
Write-Host "Syncing Clocks with Internet"
Start-Process -FilePath "c:\Windows\System32\w32tm.exe" -ArgumentList "/config /manualpeerlist:pool.ntp.org /syncfromflags:manual /reliable:yes /update"
Start-Process -FilePath "c:\Windows\System32\w32tm.exe" -ArgumentList "/resync"

#Get Screen Info
Write-Host "Getting Monitor Info"
function Decode {
    If ($args[0] -is [System.Array]) {
        [System.Text.Encoding]::ASCII.GetString($args[0]).Trim([char]0)
    }
    Else {
        "Not Found"
    }
}

[array]$screens=$null
ForEach ($monitor in Get-WmiObject WmiMonitorID -Namespace root\wmi) {  
    $result = @{}
    $result.name = Decode $monitor.UserFriendlyName -notmatch 0
    $result.serial = Decode $monitor.SerialNumberID -notmatch 0
    $result.manufacturer = Decode $monitor.ManufacturerName -notmatch 0
    $result.model = Decode $monitor.ProductCodeID -notmatch 0
    [array]$screens += $result
}

Set-Asset-Field -Subdomain $syncrodomain -Name "Attached Screens" -Value $($($screens | ConvertTo-Json) -replace '([\r]{0,1}[\n]{0,1}[\{\}][\r]{0,1}[\n]{0,1}|\,|\"|[\ ]{3,4}|[\[\]])','')

# Store ZeroNode ID
Write-Host "Checking for ZeroNode"
if (Test-Path -path "C:\ProgramData\ZeroTier\One\zerotier-one_x64.exe") {
    Write-Host "ZeroNode found recording ID"
    $nodeid = (C:\ProgramData\ZeroTier\One\zerotier-one_x64.exe -q info)
    $nodeid = $nodeid -replace '\b(?![a-zA-Z\d]{8,20})\b\S+',''
    $nodeid = $nodeid -replace ' ',''

    Write-Host $nodeid
    
    Set-Asset-Field -Subdomain $syncrodomain -Name "ZeroTier-NodeID" -Value $nodeid
}

# Get Product Keys
Write-Host "Getting Product Keys"
$pkeys = & "C:\Windows\Temp\produkey.exe" /WindowsKeys 1 /OfficeKeys 1 /IEKeys 0 /SQLKeys 1 /ExchangeKeys 1 /ExtractEdition 1 /sjson | ConvertFrom-Json
foreach ($pk in $pkeys) {
    if ($pk."Product Name" -match 'Windows') {
        Set-Asset-Field -Subdomain $syncrodomain -Name "Windows Key" -Value $($pk."Product Key")
    } elseif ($pk."Product Name" -match 'Office') {
        $okey = $okey + "$($pk."Product Name") - $($pk."Product Key") `n"
    } else {
        $prodkeys = $prodkeys + "$($pk."Product Name") - $($pk."Product Key") `n"
    }
}

Set-Asset-Field -Subdomain $syncrodomain -Name "Office Keys" -Value $($okey)
Set-Asset-Field -Subdomain $syncrodomain -Name "Product Keys" -Value $($prodkeys)

# Save Powershell Version
Set-Asset-Field -Subdomain $syncrodomain -Name "PS Version" -Value $($($Host.Version.Major).toString() + "."+ $($Host.Version.Minor).toString())

# Clean out crap printers
Write-Host "Cleaning out XPS, OneNote and Fax Printers if not shared."
Get-Printer | Where-Object {$_.Shared -eq $False} | Where-Object { $_.Name -match 'XPS' -or $_.Name -match 'OneNote' } | Remove-Printer

# Remove Bad User Share
if (Get-SMBShare | Where-Object {$_.Path -eq 'c:\Users'}) {
    & net share c:\Users /delete
}

# Get Performance Index
$WinSatResults = ((Get-CimInstance Win32_WinSAT | Select-Object CPUScore, DiskScore, D3DScore, GraphicsScore, MemoryScore, WinSPRLevel) | Out-String).trim()
Set-Asset-Field -Subdomain $syncrodomain -Name "Performance Index" -Value $($WinSatResults)
