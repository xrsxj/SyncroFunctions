function SearchResult($searchitem) {
    foreach-object { 
        foreach ($property in $_.PSObject.Properties) {
            if ($property.value -like "*$($searchitem)*") {
                $result = $_
            }
        }
    }
    return $result
}

function WritePasswords() {
    #$body.asset_password = $body.asset_password | Where-Object { $null -ne $_.Value -and $_.Value -ne 'null' }
    if ($oldpasswords.count -gt 1) {
        foreach ($oldpassword in $oldpasswords) {
            try {
                (Invoke-Restmethod -Uri "$($huduurl)/asset_passwords/$($oldpassword.id)" -Method DELETE -Headers $huduheads).data                           
            }
            catch {
                $_.Exception.Message
                "$($huduurl)/asset_passwords/$($oldpassword.id)"
            }
        }
        try {
            Write-Host "Re-Creating $($item.name)"
            (Invoke-Restmethod -Uri "$($huduurl)/asset_passwords" -Method POST -Headers $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
        }
        catch {
            $_.Exception.Message
            "$($huduurl)/companies/asset_passwords"
            $body
        }
    }
    elseif ($oldpasswords) {
        try {
            Write-Host "Updating $($item.name)"
            (Invoke-Restmethod -Uri "$($huduurl)/asset_passwords/$($oldpasswords.id)" -Method PUT -Headers $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
        }
        catch {
            $_.Exception.Message
            "$($huduurl)/asset_passwords/$($oldpasswords.id)"
            $body
        }
    }
    else {
        try {
            Write-Host "Creating $($item.name)"
            (Invoke-Restmethod -Uri "$($huduurl)/asset_passwords" -Method POST -Headers $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
        }
        catch {
            $_.Exception.Message
            "$($huduurl)/asset_passwords"
            $body
        }
    }
}
function GetHUDUPasswords() {
    $i = 1
    $passwords = New-Object System.Collections.Generic.List[System.Object]
    while ($i -lt 9999) {
        try {
            $newpasswords = (Invoke-Restmethod -Uri "$($huduurl)/asset_passwords?page=$i&page_size=500" -Headers $huduheads)
            if ($null -ne $newpasswords -and $newpasswords.asset_passwords.count -eq 0) {
                $newpasswords = $newpasswords | ConvertFrom-Json -AsHashTable
            }
        }
        catch {
            $newassets > $null
        }
        $passwords += $newpasswords.asset_passwords
        if ($($newpasswords.asset_passwords).count -lt 500) {
            break
        }
        $i++
    }
    return $passwords
}

#### FROM Unifi ########

function GetSites() {
    $Sites = (Invoke-Restmethod -Uri "$($controller)/api/self/sites" -WebSession $myWebSession).data
    return $Sites
}

function UniFiLogin() {
    try {
        Invoke-Restmethod -Uri "$($controller)/api/login" -method post -body $credential -ContentType "application/json; charset=utf-8"  -SessionVariable myWebSession | Out-Null
    }
    catch {
        Write-Host $_.Exception.Message
    }
    return $myWebSession
}
function GetPortForwards() {
    $pforwards = (Invoke-Restmethod -Uri "$($controller)/api/s/$($site.name)/stat/portforward" -WebSession $myWebSession).data
    $forwards = New-Object System.Collections.Generic.List[System.Object]

    foreach ($pforward in $pforwards) {
        $forwards += "<b>Rule</b>$($pforward.name) - $(if ($pforward.enabled -ne $true) {"<strike>"})$(if ($pforward.src) {"$($pforward.src):"})$($pforward.dst_port)/$($pforward.proto) to $($pforward.fwd):$($pforward.fwd_port)/$($pforward.proto) $(if ($pforward.enabled -ne $true) {"</strike>"})<br>"
    }
    return "$forwards"
}

function GetSpeedTest() {
    $test = New-Object System.Collections.Generic.List[System.Object]
    $end = [Math]::Floor(1000 * (Get-Date ([datetime]::UtcNow) -UFormat %s))
    $start = [Math]::Floor($end - 86400000)
    $body = @{
        attrs = 'xput_download', 'xput_upload', 'latency', 'time'
        start = $start
        end   = $end
    } | convertTo-Json
    $test = (Invoke-Restmethod -Uri "$($controller)/api/s/$($site.name)/stat/report/archive.speedtest" -WebSession $myWebSession -Method POST -ContentType "application/json" -Body $body).data[0]
    if ($test.xput_download -gt 1) {
        $testdate = Get-Date (New-Object System.DateTime (1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)).AddMilliseconds($test.time) -Format "MM-dd-yyyy HH:mm"
        $stest = "DL $([math]::Round($test.xput_download,2)) Mbps / UL $([math]::Round($test.xput_upload,2)) Mbps<br>Latency $($test.latency) ms<br>Performed: $testdate"
    }
    else {
        $stest = "No recent test available."
    }
    return "$stest"
}

function GetCompanies() {
    $i = 1
    $Companies = New-Object System.Collections.Generic.List[System.Object]
    while ($i -lt 9999) {
        $newcomps = ((Invoke-Restmethod -Uri "$($huduurl)/companies?page=$i&page_size=999" -Headers $huduheads).companies)
        $i++
        if ($newcomps.count -eq 0) {
            break
        }
        $Companies += $newcomps
    }
    return $Companies
}

function GetAssets() {
    $i = 1
    $assets = New-Object System.Collections.Generic.List[System.Object]
    while ($i -lt 9999) {
        try {
            $newassets = ((Invoke-WebRequest -Uri  "$($huduurl)/companies/$($company.id)/assets?page=$i&page_size=999" -Headers $huduheads) -creplace "CrashPlan", "CrashPlan2" | ConvertFrom-Json)
        }
        catch {
            $newassets > $null
        }
        $assets += $newassets.assets
        if ($($newassets.assets).count -lt 25) {
            break
        }
        $i++
    }
    return $assets
}

function WriteAssets() {
    $body.asset.fields = $body.asset.fields | Where-Object { $null -ne $_.value }
    if ($name -notmatch "element-") {
        if ($oldassets.count -gt 1 -and $null -ne $oldassets[0].fields) {
            foreach ($oldasset in $oldassets) {
                try {
                    (Invoke-Restmethod -Uri "$($huduurl)/companies/$($company.id)/assets/$($oldasset.id)" -Method DELETE -Headers $huduheads).data                           
                }
                catch {
                    $_.Exception.Message
                    "$($huduurl)/companies/$($company.id)/assets/$($oldasset.id)"
                }
            }
            try {
                Write-Host "Re-Creating $name"
                (Invoke-Restmethod -Uri "$($huduurl)/companies/$($company.id)/assets" -Method POST -Headers    $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
            }
            catch {
                $_.Exception.Message
                "$($huduurl)/companies/$($company.id)/assets"
                $body | ConvertTo-Json -Depth 5
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
                    (Invoke-Restmethod -Uri "$($huduurl)/companies/$($company.id)/assets/$($oldassets.id)" -Method PUT -Headers  $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
                }
                catch {
                    $_.Exception.Message
                    "$($huduurl)/companies/$($company.id)/assets/$($oldassets.id)"
                    $body | ConvertTo-Json -Depth 5
                }
            }
        }
        else {
            try {
                Write-Host "Creating $name"
                $body | Out-File -Append -FilePath "./updates.creates.log" -Encoding UTF8 
                (Invoke-Restmethod -Uri "$($huduurl)/companies/$($company.id)/assets" -Method POST -Headers  $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
            }
            catch {
                $_.Exception.Message
                "$($huduurl)/companies/$($company.id)/assets"
                $body | ConvertTo-Json -Depth 5
            }
        }
    }
}
function GetAttachedAssets($netassets) {
    $netassets = $netassets | Where-Object { $_.archived -ne "True" }
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

function SetName() {
    $name = $location + " - " + $device.name
    return $name
}
function SetLocation() {
    $location = ($site.desc -replace $company.name, "" -replace '([\)\(]| \- )', '').Trim()
    if ($location.Length -lt 2 ) {
        $location = $company.city
    }
    return $location
}
function ArchiveOldAssets() {
    if ($archiveassets.count -ne 0) {
        foreach ($archiveasset in $archiveassets) {
            if ($null -ne $archiveasset.id) {
                try {
                    Write-Host "Archiving old asset $($archiveasset.name)"
                    (Invoke-Restmethod -Uri "$($huduurl)/companies/$($company.id)/assets/$($archiveasset.id)/archive" -Method PUT -Headers $huduheads).data                           
                }
                catch {
                    $_.Exception.Message
                    "$($huduurl)/companies/$($company.id)/assets/$($archiveasset.id)/archive"
                }
            }
        }
    }
    $archiveassets = $false
}

function CreateArchiveList() {
    if ($oldassets.count -eq 0) {
        $oldassets = @{
            id = 999999999
        }
    }
    foreach ($oldasset in $oldassets) {
        if ($archiveassets -ne $false) {
            $archiveassets = $archiveassets | Where-Object { $_.id -ne $oldasset.id }
        }
        else {
            $archiveassets = $assets | Where-Object { $_.asset_layout_id -eq $templateid -and $_.fields.value -match $location -and $_.fields.value -match "Powershell Script" -and $_.id -ne $oldasset.id }
        }
    }
    return $archiveassets
}
function GetTemplateId($templatename) {
    [int]$templateid = ($Layouts | Where-Object { $_.name -eq $templatename }).id
    return $templateid
}
function GetFieldId($fieldname) {
    [int]$fieldid = (($Layouts | Where-Object { $_.id -eq $templateid }).fields | Where-Object { $_.label -eq $fieldname }).id
    return $fieldid
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
    while ($i -lt 9999) {
        try {
            $newcontacts = (Invoke-Restmethod -Uri "$($syncrourl)/contacts?api_key=$($syncrokey)&page=$i" -ContentType "application/json")
            if ($null -ne $newcontacts -and $newcontacts.contacts.count -eq 0) {
                $newcontacts = $newcontacts | ConvertFrom-Json -AsHashTable
            }
        }
        catch {
            $newcontacts > $null
        }
        $contacts += $newcontacts.contacts
        if ($($newcontacts.contacts ).count -lt 50) {
            break
        }
        $i++
    }
    return $contacts
}

