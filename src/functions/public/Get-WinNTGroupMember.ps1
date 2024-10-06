function Get-WinNTGroupMember {
    <#
        .SYNOPSIS
        Get members of a group from the WinNT provider
        .DESCRIPTION
        Get members of a group from the WinNT provider
        Convert them from COM objects into usable DirectoryEntry objects
        .INPUTS
        [System.DirectoryServices.DirectoryEntry]$DirectoryEntry
        .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] for each group member
        .EXAMPLE
        [System.DirectoryServices.DirectoryEntry]::new('WinNT://localhost/Administrators') | Get-WinNTGroupMember

        Get members of the local Administrators group
    #>
    [OutputType([System.DirectoryServices.DirectoryEntry])]
    param (

        # DirectoryEntry [System.DirectoryServices.DirectoryEntry] of the WinNT group whose members to get
        [Parameter(ValueFromPipeline)]
        $DirectoryEntry,

        # Properties of the group members to find in the directory
        [string[]]$PropertiesToLoad,

        <#
        Dictionary to cache directory entries to avoid redundant lookups

        Defaults to an empty thread-safe hashtable
        #>
        [hashtable]$DirectoryEntryCache = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain NetBIOS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByNetbios = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain SIDs as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsBySid = ([hashtable]::Synchronized(@{})),

        # Hashtable with known domain DNS names as keys and objects with Dns,NetBIOS,SID,DistinguishedName properties as values
        [hashtable]$DomainsByFqdn = ([hashtable]::Synchronized(@{})),

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

        # Log messages which have not yet been written to disk
        [hashtable]$LogBuffer = ([hashtable]::Synchronized(@{})),

        # Cache of CIM sessions and instances to reduce connections and queries
        [hashtable]$CimCache = ([hashtable]::Synchronized(@{})),

        # Output stream to send the log messages to
        [ValidateSet('Silent', 'Quiet', 'Success', 'Debug', 'Verbose', 'Output', 'Host', 'Warning', 'Error', 'Information', $null)]
        [string]$DebugOutputStream = 'Debug'

    )
    begin {

        $LogParams = @{
            ThisHostname = $ThisHostname
            Type         = $DebugOutputStream
            Buffer       = $LogBuffer
            WhoAmI       = $WhoAmI
        }

        $LogThis = @{
            ThisHostname = $ThisHostname
            LogBuffer    = $LogBuffer
            WhoAmI       = $WhoAmI
        }

        $AuthoritiesToReplaceWithParentName = @{
            'APPLICATION PACKAGE AUTHORITY' = $null
            'BUILTIN'                       = $null
            'CREATOR SID AUTHORITY'         = $null
            'LOCAL SID AUTHORITY'           = $null
            'Non-unique Authority'          = $null
            'NT AUTHORITY'                  = $null
            'NT SERVICE'                    = $null
            'NT VIRTUAL MACHINE'            = $null
            'NULL SID AUTHORITY'            = $null
            'WORLD SID AUTHORITY'           = $null
        }

        $PropertiesToLoad += 'Department',
        'description',
        'distinguishedName',
        'grouptype',
        'managedby',
        'member',
        'name',
        'objectClass',
        'objectSid',
        'operatingSystem',
        'primaryGroupToken',
        'samAccountName',
        'Title'

        $PropertiesToLoad = $PropertiesToLoad |
        Sort-Object -Unique

        $MemberParams = @{
            DirectoryEntryCache = $DirectoryEntryCache
            PropertiesToLoad    = $PropertiesToLoad
            DomainsByNetbios    = $DomainsByNetbios
            LogBuffer           = $LogBuffer
            WhoAmI              = $WhoAmI
            CimCache            = $CimCache
            ThisFqdn            = $ThisFqdn
        }

    }

    process {

        ForEach ($ThisDirEntry in $DirectoryEntry) {

            #$SourceDomain = $ThisDirEntry.Path | Split-Path -Parent | Split-Path -Leaf
            $ThisSplitPath = Split-DirectoryPath -DirectoryPath $ThisDirEntry.Path
            $SourceDomain = $ThisSplitPath['Domain']

            if (
                $null -ne $ThisDirEntry.Properties['groupType'] -or
                $ThisDirEntry.schemaclassname -in @('group', 'SidTypeWellKnownGroup', 'SidTypeAlias')
            ) {

                # Retrieve the members of local groups

                # Assembly: System.DirectoryServices.dll
                # Namespace: System.DirectoryServices
                # DirectoryEntry.Invoke(String, Object[]) Method
                # Calls a method on the native Active Directory Domain Services object
                # https://docs.microsoft.com/en-us/dotnet/api/system.directoryservices.directoryentry.invoke?view=dotnet-plat-ext-6.0

                # I am using it to call the IADsGroup::Members method
                # The IADsGroup programming interface is part of the iads.h header
                # The iads.h header is part of the ADSI component of the Win32 API
                # The IADsGroup::Members method retrieves a collection of the immediate members of the group.
                # The collection does not include the members of other groups that are nested within the group.
                # The default implementation of this method uses LsaLookupSids to query name information for the group members.
                # LsaLookupSids has a maximum limitation of 20480 SIDs it can convert, therefore that limitation also applies to this method.
                # Returns a pointer to an IADsMembers interface pointer that receives the collection of group members. The caller must release this interface when it is no longer required.
                # https://docs.microsoft.com/en-us/windows/win32/api/iads/nf-iads-iadsgroup-members
                # The IADsMembers::Members method would use the same provider but I have chosen not to implement that here
                # Recursion through nested groups can be handled outside of Get-WinNTGroupMember for now
                # Maybe that could be a feature in the future
                # https://docs.microsoft.com/en-us/windows/win32/adsi/adsi-object-model-for-winnt-providers?redirectedfrom=MSDN

                $DirectoryMembers = & { $ThisDirEntry.Invoke('Members') } 2>$null
                Write-LogMsg @LogParams -Text " # '$($ThisDirEntry.Path)' has $(($DirectoryMembers | Measure-Object).Count) members # For $($ThisDirEntry.Path)"

                $MembersToGet = @{
                    'WinNTMembers' = @()
                }

                ForEach ($DirectoryMember in $DirectoryMembers) {

                    # The IADsGroup::Members method returns ComObjects
                    # But proper .Net objects are much easier to work with
                    # So we will convert the ComObjects into DirectoryEntry objects

                    $DirectoryPath = Invoke-ComObject -ComObject $DirectoryMember -Property 'ADsPath'
                    $MemberDomainDn = $null
                    #####$DirectorySplit = Split-DirectoryPath -DirectoryPath $DirectoryPath

                    <#
                    WinNT://WORKGROUP/COMPUTER/Administrator
                    WinNT://COMPUTER/Administrators
                    WinNT://DOMAIN/COMPUTER/Administrator
                    WinNT://WORKGROUP/COMPUTER/GuestAccount
                    #>
                    $workgroupregex = 'WinNT:\/\/(WORKGROUP\/)?(?<Domain>[^\/]*)\/(?<Acct>.*$)'
                    if ($DirectoryPath -match $workgroupregex) {

                        $MemberName = $Matches.Acct
                        Write-LogMsg @LogParams -Text " # Local computer of '$($Matches.Domain)' and an account name of '$MemberName' # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                        $MemberDomainNetbios = $Matches.Domain

                        # Replace the well-known SID authorities with the computer name
                        if ($AuthoritiesToReplaceWithParentName.ContainsKey($MemberDomainNetbios)) {

                            # Possibly a debugging issue, not sure whether I need to prepare for both here.
                            # in vscode Watch shows it as a DirectoryEntry with properties but the console (and results) have it as a String
                            if ($ThisDirEntry.Parent.GetType().Name -eq 'String') {

                                $LastIndexOf = $ThisDirEntry.Parent.LastIndexOf('/')
                                $ResolvedMemberDomainNetbios = $ThisDirEntry.Parent.Substring($LastIndexOf + 1, $ThisDirEntry.Parent.Length - $LastIndexOf - 1)

                            } elseif ($ThisDirEntry.Parent.GetType().Name -eq 'DirectoryEntry') {
                                $ResolvedMemberDomainNetbios = $ThisDirEntry.Parent.Name
                            }

                            $DirectoryPath = $DirectoryPath.Replace($MemberDomainNetbios, $ResolvedMemberDomainNetbios)
                            $ResolvedMemberDomainNetbios = $MemberDomainNetbios

                        }

                        $DomainCacheResult = $DomainsByNetbios[$MemberDomainNetbios]

                        if ($DomainCacheResult) {

                            Write-LogMsg @LogParams -Text " # Domain NetBIOS cache hit for '$MemberDomainNetBios' # For '$DirectoryPath' # For $($ThisDirEntry.Path)"

                            if ( "WinNT:\\$MemberDomainNetbios" -ne $SourceDomain ) {
                                $MemberDomainDn = $DomainCacheResult.DistinguishedName
                            }

                        } else {
                            Write-LogMsg @LogParams -Text " # Domain NetBIOS cache miss for '$MemberDomainNetBios'. Available keys: $($DomainsByNetBios.Keys -join ',') # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                        }

                        # WinNT://WORKGROUP/COMPUTER/GuestAccount
                        if ($DirectoryPath -match 'WinNT:\/\/(?<Domain>[^\/]*)\/(?<Middle>[^\/]*)\/(?<Acct>.*$)') {

                            Write-LogMsg @LogParams -Text " # Name '$($Matches.Acct)' is on ADSI server '$($Matches.Middle)' joined to the domain '$($Matches.Domain)' # For '$DirectoryPath' # For $($ThisDirEntry.Path)"

                            if ($Matches.Middle -eq $SourceDomain) {
                                $MemberDomainDn = $null
                            }

                        } else {
                            Write-LogMsg @LogParams -Text " # No RegEx match for 'WinNT:\/\/(?<Domain>[^\/]*)\/(?<Middle>[^\/]*)\/(?<Acct>.*$)' # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                        }

                    } else {
                        Write-LogMsg @LogParams -Text " # No RegEx match for '$workgroupregex' # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                    }

                    # LDAP directories have a distinguishedName
                    if ($MemberDomainDn) {

                        # LDAP directories support searching
                        # Combine all members' samAccountNames into a single search per directory distinguishedName
                        # Use a hashtable with the directory path as the key and a string as the definition
                        # The string is a partial LDAP filter, just the segments of the LDAP filter for each samAccountName
                        Write-LogMsg @LogParams -Text " # '$MemberName' is a domain security principal # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                        $MembersToGet["LDAP://$MemberDomainDn"] += "(samaccountname=$MemberName)"

                    } else {

                        # WinNT directories do not support searching so we will retrieve each member individually
                        # Use a hashtable with 'WinNTMembers' as the key and an array of WinNT directory paths as the value
                        Write-LogMsg @LogParams -Text " # Is a local security principal # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                        $MembersToGet['WinNTMembers'] += $DirectoryPath

                    }

                }

                # Get and Expand the directory entries for the WinNT group members
                ForEach ($ThisMember in $MembersToGet['WinNTMembers']) {

                    Write-LogMsg @LogParams -Text "Get-DirectoryEntry -DirectoryPath '$ThisMember' # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                    $MemberDirectoryEntry = Get-DirectoryEntry -DirectoryPath $ThisMember @MemberParams
                    Expand-WinNTGroupMember -DirectoryEntry $MemberDirectoryEntry -DomainsByFqdn $DomainsByFqdn -DomainsBySid $DomainsBySid @MemberParams @LogThis

                }

                # Remove the WinNTMembers key from the hashtable so the only remaining keys are distinguishedName(s) of LDAP directories
                $MembersToGet.Remove('WinNTMembers')

                # Get and Expand the directory entries for the LDAP group members
                ForEach ($MemberPath in $MembersToGet.Keys) {

                    Write-LogMsg @LogParams -Text "Search-Directory -DirectoryPath '$ThisMember' # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
                    $MemberDirectoryEntries = Search-Directory -DirectoryPath $MemberPath -Filter "(|$($MembersToGet[$Key]))" @MemberParams
                    Expand-WinNTGroupMember -DirectoryEntry $MemberDirectoryEntries -DomainsByFqdn $DomainsByFqdn -DomainsBySid $DomainsBySid @MemberParams @LogThis

                }

            } else {
                Write-LogMsg @LogParams -Text " # '$($ThisDirEntry.Path)' is not a group # For '$DirectoryPath' # For $($ThisDirEntry.Path)"
            }

        }

    }

}
