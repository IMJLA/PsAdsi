function Get-AdsiGroup {

    <#
    .SYNOPSIS
    Get the directory entries for a group and its members using ADSI
    .DESCRIPTION
    Uses the ADSI components to search a directory for a group, then get its members
    Both the WinNT and LDAP providers are supported
    .INPUTS
    None. Pipeline input is not accepted.
    .OUTPUTS
    [System.DirectoryServices.DirectoryEntry] for each group memeber
    .EXAMPLE
    Get-AdsiGroup -DirectoryPath 'WinNT://WORKGROUP/localhost' -GroupName Administrators

    Get members of the local Administrators group
    .EXAMPLE
    Get-AdsiGroup -GroupName Administrators

    On a domain-joined computer, this will get members of the domain's Administrators group
    On a workgroup computer, this will get members of the local Administrators group
    #>

    [OutputType([System.DirectoryServices.DirectoryEntry])]

    param (

        <#
        Path to the directory object to retrieve
        Defaults to the root of the current domain
        #>
        [string]$DirectoryPath = (([System.DirectoryServices.DirectorySearcher]::new()).SearchRoot.Path),

        # Name (CN or Common Name) of the group to retrieve
        [string]$GroupName,

        # Properties of the group members to retrieve
        [string[]]$PropertiesToLoad = @('distinguishedName', 'groupType', 'member', 'name', 'objectClass', 'objectSid', 'primaryGroupToken', 'samAccountName'),

        # In-process cache to reduce calls to other processes or to disk
        [Parameter(Mandatory)]
        [ref]$Cache

    )

    $Log = @{ 'Cache' = $Cache ; 'Suffix' = " # for ADSI group '$GroupName'" }

    $GroupParams = @{
        'Cache'            = $Cache
        'DirectoryPath'    = $DirectoryPath
        'PropertiesToLoad' = $PropertiesToLoad
    }

    $GroupMemberParams = @{
        'Cache'            = $Cache
        'PropertiesToLoad' = $PropertiesToLoad
    }

    # Add the bare minimum required properties
    $PropertiesToLoad = $PropertiesToLoad + @(
        'distinguishedName',
        'grouptype',
        'member',
        'name',
        'objectClass',
        'objectSid',
        'primaryGroupToken',
        'samAccountName'
    )

    $PropertiesToLoad = $PropertiesToLoad |
    Sort-Object -Unique

    switch -Regex ($DirectoryPath) {
        '^WinNT' {
            $GroupParams['DirectoryPath'] = "$DirectoryPath/$GroupName"
            Write-LogMsg @Log -Text 'Get-DirectoryEntry' -Expand $GroupParams -MapKeyName 'LogCacheMap'
            $GroupMemberParams['DirectoryEntry'] = Get-DirectoryEntry @GroupParams
            Write-LogMsg @Log -Text 'Get-WinNTGroupMember' -Expand $GroupMemberParams -MapKeyName 'LogCacheMap'
            $FullMembers = Get-WinNTGroupMember @GroupMemberParams
            break
        }
        '^$' {
            # This is expected for a workgroup computer
            $GroupParams['DirectoryPath'] = "WinNT://localhost/$GroupName"
            Write-LogMsg @Log -Text 'Get-DirectoryEntry' -Expand $GroupParams -MapKeyName 'LogCacheMap'
            $GroupMemberParams['DirectoryEntry'] = Get-DirectoryEntry @GroupParams
            Write-LogMsg @Log -Text 'Get-WinNTGroupMember' -Expand $GroupMemberParams -MapKeyName 'LogCacheMap'
            $FullMembers = Get-WinNTGroupMember @GroupMemberParams
            break
        }
        default {

            if ($GroupName) {
                $GroupParams['Filter'] = "(&(objectClass=group)(cn=$GroupName))"
            } else {
                $GroupParams['Filter'] = '(objectClass=group)'
            }

            Write-LogMsg @Log -Text 'Search-Directory' -Expand $GroupParams -MapKeyName 'LogCacheMap'
            $GroupMemberParams['Group'] = Search-Directory @GroupParams
            Write-LogMsg @Log -Text 'Get-AdsiGroupMember' -Expand $GroupMemberParams -MapKeyName 'LogCacheMap'
            $FullMembers = Get-AdsiGroupMember @GroupMemberParams
        }

    }

    return $FullMembers

}
