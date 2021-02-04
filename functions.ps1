function WriteAssets() {
    $body.asset.fields = $body.asset.fields | Where-Object { $null -ne $_.value -and $_.value -ne "" }
    if ($name -notmatch "element-") {
        if ($oldassets.count -gt 1 -and $oldassets[0].fields) {
            foreach ($oldasset in $oldassets) {
                try {
                    $response = (Invoke-Restmethod -Uri "$($huduurl)/companies/$($huduid)/assets/$($oldasset.id)" -Method DELETE -Headers $huduheads)
                }
                catch {
                    Write-Host "Failed to DELETE $($body.asset.name)"
                    $response
                    $body | ConvertTo-Json -depth 6
                }
            }
            try {
                Write-Host "Re-Creating $name"
                $response = (Invoke-Restmethod -Uri "$($huduurl)/companies/$($huduid)/assets" -Method POST -Headers $huduheads -Body $($body | ConvertTo-Json -depth 6))
            }
            catch {
                Write-Host "Failed to CREATE $($body.asset.name)"
                Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
                $response
                $body | ConvertTo-Json -depth 6
            }
        }
        elseif ($oldassets) {
            if ($oldassets[0].fields) {
                $oldasset = $oldassets | Select-Object -First 1
            }
            else {
                $oldasset = $oldassets
            }
            $body.asset.fields |
            ForEach-Object {
                if ($_.value -notmatch '/a/') {
                    if ( $oldasset.fields.value -contains $_.value -or $null -eq $_.value) {
                        $asset_layout_field_id = $_.asset_layout_field_id
                        $body.asset.fields = [array]($body.asset.fields | Where-Object { $_.asset_layout_field_id -ne $asset_layout_field_id })
                    }
                }
                else {
                    $tempbody = 0
                    $_.value | ForEach-Object {
                        if (($oldasset.fields.value | Where-Object { $_ -match '/a/' } | ConvertFrom-Json).id -notcontains $_.id ) {
                            $tempbody ++
                        }
                    }
                    if ($tempbody -eq 0 ) {
                        $asset_layout_field_id = $_.asset_layout_field_id
                        $body.asset.fields = [array]($body.asset.fields | Where-Object { $_.asset_layout_field_id -ne $asset_layout_field_id })
                    }
                }
            }
            if ($null -eq $body.asset.fields) {
                $body.asset = $body.asset | Select-Object -Property * -ExcludeProperty fields
            }
            if ($body.asset.fields) {
                try {
                    Write-Host "Updating $($company.name) $name"
                    $response = (Invoke-Restmethod -Uri "$($huduurl)/companies/$($huduid)/assets/$($oldassets.id)" -Method PUT -Headers  $huduheads -Body $($body | ConvertTo-Json -depth 6))
                }
                catch {
                    Write-Host "Failed to UPDATE $($body.asset.name)"
                    $response
                    $body | ConvertTo-Json -depth 6
                }
            }
        }
        else {
            try {
                Write-Host "Creating $name"
                $response = (Invoke-Restmethod -Uri "$($huduurl)/companies/$($huduid)/assets" -Method POST -Headers  $huduheads -Body $($body | ConvertTo-Json -depth 6))
            }
            catch {
                Write-Host "Failed to CREATE $($body.asset.name)"
                $response
                $body | ConvertTo-Json -depth 6
            }
        }
    }
}
function GetAttachedAssets($netassets) {
    if ($netassets) {
        $attachedassets = New-Object System.Collections.Generic.List[System.Object]
        foreach ($asset in $netassets) {
            $attachedassets.Add(@{name = $asset.name
                    id                 = $asset.id
                    url                = $asset.url
                })
        }
        $attachedassets.Add(@{})
        $attachedassets = ($attachedassets | ConvertTo-Json) -replace '\r\n', '' -replace '  ', ''
    }
    else {
        $attachedassets = ""
    }
    return $attachedassets
}
function GetDomainStructure ([string]$dn, $level = 1) { 
    if ($level -eq 1) { "<b><u>$((Get-ADDomain).DNSRoot)</b></u><br>" } 
    Get-ADObject -filter 'ObjectClass -eq "organizationalUnit" -or ObjectClass -eq "Container"' -SearchBase $dn -SearchScope OneLevel |  
    Sort-Object -Property distinguishedName |  
    ForEach-Object { 
        $components = ($_.name).split(',') 
        "<b>$('&ensp;' * $level)$($components[0])</b><br>" 
        Get-ADObject -Filter 'ObjectClass -ne "organizationalUnit" -and ObjectClass -ne "Container"' -SearchBase $_.distinguishedName -SearchScope OneLevel | 
        ForEach-Object { 
            "$('&ensp;&ensp;' * $level)$($_.Name)<br>" 
        }
        if ($_.ObjectClass -ne "Container") {
            GetDomainStructure -dn $_.distinguishedName -level ($level + 1) 
        }
    } 
}
function GetSyncContacts() {
    $i = 1
    $contacts = New-Object System.Collections.Generic.List[System.Object]
    do {
        $newcontacts = (Invoke-Restmethod -Uri "$($syncrourl)/contacts?customer_id=$($customer_id)&page=$i" -ContentType "application/json" -Headers $syncroheads)
        $contacts += $newcontacts.contacts
        $i++
    } while ($newcontacts.contacts.count -eq $newcontacts.meta.per_page)
    return $contacts
}
function GetAssets() {
    $i = 1
    $assets = New-Object System.Collections.Generic.List[System.Object]
    do {
        #$newassets = ((Invoke-WebRequest -Uri  "$($huduurl)/companies/$($company.id)/assets?page=$i&page_size=999" -Headers $huduheads) -creplace "CrashPlan", "CrashPlan2" | ConvertFrom-Json)
        $tempassets = (Invoke-RestMethod -Uri  "$($huduurl)/companies/$($company.id)/assets?page=$i&page_size=999" -Headers $huduheads)
        if ($tempassets.assets.count -eq 0) {
            try {
                $tempassets = $tempassets -creplace "CrashPlan", "CrashPlan2" -creplace "os", "os2"  -creplace "model", "model1" | ConvertFrom-Json
            } catch {
                break
            }
        }
        $newassets = $tempassets
        $assets += $newassets.assets
        $i++
        $newassets.assets.count
    } while ($newassets.assets.count -ne 0)
    return $assets
}
function Ping-IPRange {
    [CmdletBinding(ConfirmImpact = 'Low')]
    Param(
        [parameter(Mandatory = $true, Position = 0)]
        [System.Net.IPAddress]$StartAddress,
        [parameter(Mandatory = $true, Position = 1)]
        [System.Net.IPAddress]$EndAddress,
        [int]$Interval = 30,
        [Switch]$RawOutput = $false
    )

    $timeout = 2000

    function New-Range ($start, $end) {

        [byte[]]$BySt = $start.GetAddressBytes()
        [Array]::Reverse($BySt)
        [byte[]]$ByEn = $end.GetAddressBytes()
        [Array]::Reverse($ByEn)
        $i1 = [System.BitConverter]::ToUInt32($BySt, 0)
        $i2 = [System.BitConverter]::ToUInt32($ByEn, 0)
        for ($x = $i1; $x -le $i2; $x++) {
            $ip = ([System.Net.IPAddress]$x).GetAddressBytes()
            [Array]::Reverse($ip)
            [System.Net.IPAddress]::Parse($($ip -join '.'))
        }
    }
    
    $IPrange = New-Range $StartAddress $EndAddress

    $IpTotal = $IPrange.Count

    Get-Event -SourceIdentifier "ID-Ping*" | Remove-Event
    Get-EventSubscriber -SourceIdentifier "ID-Ping*" | Unregister-Event

    $IPrange | foreach {

        [string]$VarName = "Ping_" + $_.Address

        New-Variable -Name $VarName -Value (New-Object System.Net.NetworkInformation.Ping)

        Register-ObjectEvent -InputObject (Get-Variable $VarName -ValueOnly) -EventName PingCompleted -SourceIdentifier "ID-$VarName"

        (Get-Variable $VarName -ValueOnly).SendAsync($_, $timeout, $VarName)

        Remove-Variable $VarName

        try {

            $pending = (Get-Event -SourceIdentifier "ID-Ping*").Count

        }
catch [System.InvalidOperationException] {}

        $index = [array]::indexof($IPrange, $_)
    
        Start-Sleep -Milliseconds $Interval
    }

    While ($pending -lt $IpTotal) {

        Wait-Event -SourceIdentifier "ID-Ping*" | Out-Null

        Start-Sleep -Milliseconds 10

        $pending = (Get-Event -SourceIdentifier "ID-Ping*").Count

    }

    if ($RawOutput) {
        
        $Reply = Get-Event -SourceIdentifier "ID-Ping*" | ForEach { 
            If ($_.SourceEventArgs.Reply.Status -eq "Success") {
                $_.SourceEventArgs.Reply
            }
            Unregister-Event $_.SourceIdentifier
            Remove-Event $_.SourceIdentifier
        }
    
    }
else {

        $Reply = Get-Event -SourceIdentifier "ID-Ping*" | ForEach { 
            If ($_.SourceEventArgs.Reply.Status -eq "Success") {
                $_.SourceEventArgs.Reply | select @{
                      Name = "IPAddress"   ; Expression = { $_.Address }
                },
                    @{Name = "Bytes"       ; Expression = { $_.Buffer.Length } },
                    @{Name = "Ttl"         ; Expression = { $_.Options.Ttl } },
                    @{Name = "ResponseTime"; Expression = { $_.RoundtripTime } }
            }
            Unregister-Event $_.SourceIdentifier
            Remove-Event $_.SourceIdentifier
        }
    }
    if ($Reply -eq $Null) {
        Write-Verbose "Ping-IPrange : No ip address responded" -Verbose
    }

    return $Reply
}
function Get-IPrangeStartEnd {
    param (  
      [string]$start,  
      [string]$end,  
      [string]$ip,  
      [string]$mask,  
      [int]$cidr  
    )  
      
    function IP-toINT64 () {  
      param ($ip)  
      
      $octets = $ip.split(".")  
      return [int64]([int64]$octets[0] * 16777216 + [int64]$octets[1] * 65536 + [int64]$octets[2] * 256 + [int64]$octets[3])  
    }  
      
    function INT64-toIP() {  
      param ([int64]$int)  
 
      return (([math]::truncate($int / 16777216)).tostring() + "." + ([math]::truncate(($int % 16777216) / 65536)).tostring() + "." + ([math]::truncate(($int % 65536) / 256)).tostring() + "." + ([math]::truncate($int % 256)).tostring() ) 
    }  
      
    if ($ip) { $ipaddr = [Net.IPAddress]::Parse($ip) }  
    if ($cidr) { $maskaddr = [Net.IPAddress]::Parse((INT64-toIP -int ([convert]::ToInt64(("1" * $cidr + "0" * (32 - $cidr)), 2)))) }  
    if ($mask) { $maskaddr = [Net.IPAddress]::Parse($mask) }  
    if ($ip) { $networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address) }  
    if ($ip) { $broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address)) }  
      
    if ($ip) {  
      $startaddr = IP-toINT64 -ip $networkaddr.ipaddresstostring  
      $endaddr = IP-toINT64 -ip $broadcastaddr.ipaddresstostring  
    }
 else {  
      $startaddr = IP-toINT64 -ip $start  
      $endaddr = IP-toINT64 -ip $end  
    }  
      
     $temp = "" | Select start, end 
     $temp.start = INT64-toIP -int $startaddr 
     $temp.end = INT64-toIP -int $endaddr 
     return $temp 
}
function GetShareAccessRights() {
    $accesses = Get-SMBShareAccess -Name $share.Name
    $accessrights = New-Object System.Collections.Generic.List[System.Object]

    foreach ($access in $accesses) {
        $accessrights += "$($access.AccountName) : $($access.AccessControlType) $($access.AccessRight)<br>"
    }
    return "$accessrights"
}
function GetFileAccessRights() {
    $accesses = (get-acl $($share.Path)).access 
    $accessrights = New-Object System.Collections.Generic.List[System.Object]

    foreach ($access in $accesses) {
        $accessrights += "$($access.IdentityReference) : $($access.AccessControlType) $($access.FileSystemRights)<br>"
    }
    return "$accessrights"
}
function FormatFileList() {
    $fileslist = New-Object System.Collections.Generic.List[System.Object]
    try {
        $files = Get-ChildItem -Path "$($Share.Path)" -Name
        foreach ($file in $files) {
            $fileslist += "$file<br>"
        }
    }
    catch {
        $fileslist += "Access Denied!"
    }
    return "$fileslist"
}
