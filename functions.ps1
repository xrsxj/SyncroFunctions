function WriteAssets() {
    $body.asset.fields = $body.asset.fields | Where-Object { $null -ne $_.value -and $_.value -ne "" }
    if ($name -notmatch "element-") {
        if ($oldassets.count -gt 1 -and $oldassets[0].fields) {
            foreach ($oldasset in $oldassets) {
                try {
                    (Invoke-Restmethod -Uri "$($huduurl)/companies/$huduid/assets/$($oldasset.id)" -Method DELETE -Headers $huduheads).data                           
                }
                catch {
                    $_.Exception.Message
                    "$($huduurl)/companies/$huduid/assets/$($oldasset.id)"
                }
            }
            try {
                Write-Host "Re-Creating $name"
                (Invoke-Restmethod -Uri "$($huduurl)/companies/$huduid/assets" -Method POST -Headers    $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
            }
            catch {
                $_.Exception.Message
                "$($huduurl)/companies/$huduid/assets"
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
                    (Invoke-Restmethod -Uri "$($huduurl)/companies/$huduid/assets/$($oldassets.id)" -Method PUT -Headers  $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
                }
                catch {
                    $_.Exception.Message
                    "$($huduurl)/companies/$huduid/assets/$($oldassets.id)"
                    $body | ConvertTo-Json -Depth 5
                }
            }
        }
        else {
            try {
                Write-Host "Creating $name"
                $body | Out-File -Append -FilePath "./updates.creates.log" -Encoding UTF8 
                (Invoke-Restmethod -Uri "$($huduurl)/companies/$huduid/assets" -Method POST -Headers  $huduheads -Body $($body | ConvertTo-Json -depth 6)).data
            }
            catch {
                $_.Exception.Message
                "$($huduurl)/companies/$huduid/assets"
                $body | ConvertTo-Json -Depth 5
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
function GetAssets() {
    $i = 1
    $assets = New-Object System.Collections.Generic.List[System.Object]
    while ($i -lt 9999) {
        try {
            $newassets = ((Invoke-WebRequest -UseBasicParsing -Uri "$($huduurl)/companies/$huduid/assets?page=$i&page_size=999" -Headers $huduheads) -creplace "CrashPlan", "CrashPlan2" | ConvertFrom-Json)
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