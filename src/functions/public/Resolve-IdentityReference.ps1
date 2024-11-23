function Resolve-IdentityReference {

    <#
    .SYNOPSIS
    Use CIM and ADSI to lookup info about IdentityReferences from Access Control Entries that came from Discretionary Access Control Lists
    .DESCRIPTION
    Based on the IdentityReference proprety of each Access Control Entry:
    Resolve SID to NT account name and vise-versa
    Resolve well-known SIDs
    Resolve generic defaults like 'NT AUTHORITY' and 'BUILTIN' to the applicable computer or domain name
    .INPUTS
    None. Pipeline input is not accepted.
    .OUTPUTS
    [PSCustomObject] with IdentityReferenceNetBios,IdentityReferenceDns, and SIDString properties (each strings)
    .EXAMPLE
    Resolve-IdentityReference -IdentityReference 'BUILTIN\Administrator' -AdsiServer (Get-AdsiServer 'localhost')

    Get information about the local Administrator account
    #>

    [OutputType([PSCustomObject])]
    param (

        # IdentityReference from an Access Control Entry
        # Expecting either a SID (S-1-5-18) or an NT account name (CONTOSO\User)
        [Parameter(Mandatory)]
        [string]$IdentityReference,

        # Object from Get-AdsiServer representing the directory server and its attributes
        [PSObject]$AdsiServer,

        <#
        Dictionary to cache known servers to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$AdsiServersByDns = [hashtable]::Synchronized(@{}),
        <#
        Hostname of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE
        #>
        [string]$ThisHostName = (HOSTNAME.EXE),

        <#
        FQDN of the computer running this function.

        Can be provided as a string to avoid calls to HOSTNAME.EXE and [System.Net.Dns]::GetHostByName()
        #>
        [string]$ThisFqdn = ([System.Net.Dns]::GetHostByName((HOSTNAME.EXE)).HostName),

        # Username to record in log messages (can be passed to Write-LogMsg as a parameter to avoid calling an external process)
        [string]$WhoAmI = (whoami.EXE),

        # Output stream to send the log messages to
        [ValidateSet('Silent', 'Quiet', 'Success', 'Debug', 'Verbose', 'Output', 'Host', 'Warning', 'Error', 'Information', $null)]
        [string]$DebugOutputStream = 'Debug',

        # Output from Get-KnownSidHashTable
        [hashtable]$WellKnownSidBySid = (Get-KnownSidHashTable),

        # Output from Get-KnownCaptionHashTable
        [hashtable]$WellKnownSidByCaption = (Get-KnownCaptionHashTable -WellKnownSidBySid $WellKnownSidBySid),

        # In-process cache to reduce calls to other processes or to disk
        [Parameter(Mandatory)]
        [ref]$Cache

    )

    $Log = @{ ThisHostname = $ThisHostname ; Type = $DebugOutputStream ; Buffer = $Cache.Value['LogBuffer'] ; WhoAmI = $WhoAmI }
    $LogThis = @{ ThisHostname = $ThisHostname ; Cache = $Cache ; WhoAmI = $WhoAmI ; DebugOutputStream = $DebugOutputStream }
    $ServerNetBIOS = $AdsiServer.Netbios
    $splat1 = @{ WellKnownSidBySid = $WellKnownSidBySid ; WellKnownSidByCaption = $WellKnownSidByCaption }
    $splat3 = @{ AdsiServer = $AdsiServer; ServerNetBIOS = $ServerNetBIOS }
    $splat5 = @{ ThisFqdn = $ThisFqdn }
    $splat8 = @{ IdentityReference = $IdentityReference }

    # Search for the IdentityReference in the cache of Win32_Account CIM instances and well-known SIDs on the ADSI server. Many cannot be translated with the Translate method.
    $CacheResult = Resolve-IdRefCached -IdentityReference $IdentityReference @splat3

    if ($null -ne $CacheResult) {

        #Write-LogMsg @Log -Text " # IdentityReference '$IdentityReference' # Cache hit"
        return $CacheResult

    }

    #Write-LogMsg @Log -Text " # IdentityReference '$IdentityReference' # Cache miss"

    <#
    If no match was found in any cache, the resolution method depends on the IdentityReference.
    First, determine whether the IdentityReference is an NTAccount (DOMAIN\Name vs Name).
    #>

    $LastSlashIndex = $IdentityReference.LastIndexOf('\')

    if ($LastSlashIndex -eq -1) {

        $Name = $IdentityReference
        $Domain = ''

    } else {

        $StartIndex = $LastSlashIndex + 1
        $Name = $IdentityReference.Substring( $StartIndex , $IdentityReference.Length - $StartIndex )
        $Domain = $IdentityReference.Substring( 0 , $StartIndex - 1 )

    }

    # Determine whether the IdentityReference's domain is a well-known SID authority.
    $ScriptBlocks = @{
        'NT SERVICE'                    = { Resolve-IdRefSvc -Name $Name @splat3 @splat5 @splat8 @LogThis }
        'APPLICATION PACKAGE AUTHORITY' = { Resolve-IdRefAppPkgAuth -Name $Name @splat1 @splat3 @splat5 @splat8 @LogThis }
        'BUILTIN'                       = { Resolve-IdRefBuiltIn -Name $Name @splat3 @splat5 @splat8 @LogThis }
    }

    $ScriptToRun = $ScriptBlocks[$Domain]

    # If the IdentityReference's domain is a well-known SID authority, resolve the IdentityReference accordingly.
    if ($null -ne $ScriptToRun) {

        $KnownAuthorityResult = & $ScriptToRun

        if ($null -ne $KnownAuthorityResult) {

            #Write-LogMsg @Log -Text " # IdentityReference '$IdentityReference' # Known SID authority used for successful IdentityReference resolution"
            return $KnownAuthorityResult

        }

    }

    # If the IdentityReference's domain is not a well-known SID authority, determine whether the IdentityReference is a Revision 1 SID.
    if ($Name.Substring(0, 4) -eq 'S-1-') {

        # If the IdentityReference is a Revision 1 SID, translate the SID to an NTAccount.
        $Resolved = Resolve-IdRefSID -AdsiServersByDns $AdsiServersByDns @splat3 @splat5 @splat8 @LogThis
        return $Resolved

    }

    # If no match was found with any of the known patterns for SIDs or well-known SID authorities, the IdentityReference is an NTAccount.
    # Translate the NTAccount to a SID.
    if ($null -ne $ServerNetBIOS) {

        # Start by determining the domain DN and DNS name.
        $CacheResult = $null
        $TryGetValueResult = $Cache.Value['DomainByNetbios'].Value.TryGetValue( $ServerNetBIOS, [ref]$CacheResult )

        if ($TryGetValueResult) {
            #Write-LogMsg @Log -Text " # IdentityReference '$IdentityReference' # Domain NetBIOS cache hit for '$ServerNetBIOS'"
        } else {

            #Write-LogMsg @Log -Text " # IdentityReference '$IdentityReference' # Domain NetBIOS cache miss for '$ServerNetBIOS'"
            $CacheResult = Get-AdsiServer -Netbios $ServerNetBIOS @splat5 @LogThis

        }

        $DomainDn = $CacheResult.DistinguishedName
        $DomainDns = $CacheResult.Dns

        # Try to resolve the account against the server the Access Control Entry came from (which may or may not be the directory server for the account).
        $SIDString = ConvertTo-SidString -Name $Name -ServerNetBIOS $ServerNetBIOS -Log $Log

        if (-not $SIDString) {

            # Try to resolve the account against the domain indicated in its NT Account Name.
            # Add this domain to our list of known domains.
            $SIDString = Resolve-IdRefSearchDir -DomainDn $DomainDn -Log $Log -LogThis $LogThis -Name $Name @splat5 @splat8

        }

        if (-not $SIDString) {

            # Try to find the DirectoryEntry object directly on the server.
            $SIDString = Resolve-IdRefGetDirEntry -Name $Name -splat5 $splat5 -Log $Log @splat3

        }

        # The IdentityReference is an unresolved SID (deleted account, account in a domain with a broken domain trust, etc.)
        if ( '' -eq "$Name" ) {

            $Name = $IdentityReference
            Write-LogMsg @Log -Text " # IdentityReference '$IdentityReference' # No name could be parsed."

        } else {
            Write-LogMsg @Log -Text " # IdentityReference '$IdentityReference' # Name parsed is '$Name'."
        }

        return [PSCustomObject]@{
            IdentityReference        = $IdentityReference
            SIDString                = $SIDString
            IdentityReferenceNetBios = "$ServerNetBIOS\$Name"
            IdentityReferenceDns     = "$DomainDns\$Name"
        }

    }

}
