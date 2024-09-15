function New-FakeDirectoryEntry {

    <#
    Used in place of a DirectoryEntry for certain WinNT security principals that do not have objects in the directory
    The WinNT provider only throws an error if you try to retrieve certain accounts/identities
    #>

    param (
        [string]$DirectoryPath,
        [string]$SID,
        [string]$Description
    )

    $LastSlashIndex = $DirectoryPath.LastIndexOf('/')
    $StartIndex = $LastSlashIndex + 1
    $Name = $DirectoryPath.Substring($StartIndex, $DirectoryPath.Length - $StartIndex)
    $Parent = $DirectoryPath.Substring(0, $LastSlashIndex)
    $SchemaEntry = [System.DirectoryServices.DirectoryEntry]
    $objectSid = ConvertTo-SidByteArray -SidString $SID
    switch -Wildcard ($DirectoryPath) {
        '*/ALL APPLICATION PACKAGES' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-15-2-1'
            $Description = 'All applications running in an app package context. SECURITY_BUILTIN_PACKAGE_ANY_PACKAGE'
            $SchemaClassName = 'group'
            break
        }
        '*/ALL RESTRICTED APPLICATION PACKAGES' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-15-2-2'
            $Description = 'SECURITY_BUILTIN_PACKAGE_ANY_RESTRICTED_PACKAGE'
            $SchemaClassName = 'group'
            break
        }
        '*/ANONYMOUS LOGON' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-15-7'
            $Description = 'A user who has connected to the computer without supplying a user name and password. Not a member of Authenticated Users.'
            $SchemaClassName = 'user'
            break
        }
        '*/Authenticated Users' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-5-11'
            $Description = 'A group that includes all users and computers with identities that have been authenticated.'
            $SchemaClassName = 'group'
            break
        }
        '*/CREATOR OWNER' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-3-0'
            $Description = 'A SID to be replaced by the SID of the user who creates a new object. This SID is used in inheritable ACEs.'
            $SchemaClassName = 'user'
            break
        }
        '*/Everyone' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-1-0'
            $Description = "A group that includes all users; aka 'World'."
            $SchemaClassName = 'group'
            break
        }
        '*/INTERACTIVE' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-5-4'
            $Description = 'Users who log on for interactive operation. This is a group identifier added to the token of a process when it was logged on interactively.'
            $SchemaClassName = 'group'
            break
        }
        '*/LOCAL SERVICE' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-5-19'
            $Description = 'A local service account'
            $SchemaClassName = 'user'
            break
        }
        '*/NETWORK SERVICE' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-5-20'
            $Description = 'A network service account'
            $SchemaClassName = 'user'
            break
        }
        '*/SYSTEM' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-5-18'
            $Description = 'By default, the SYSTEM account is granted Full Control permissions to all files on an NTFS volume'
            $SchemaClassName = 'user'
            break
        }
        '*/TrustedInstaller' {
            $objectSid = ConvertTo-SidByteArray -SidString 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
            $Description = 'Most of the operating system files are owned by the TrustedInstaller security identifier (SID)'
            $SchemaClassName = 'user'
            break
        }
    }

    $Properties = @{
        Name            = $Name
        Description     = $Description
        objectSid       = $objectSid
        SchemaClassName = $SchemaClassName
    }

    $Object = [PSCustomObject]@{
        Name            = $Name
        Description     = $Description
        objectSid       = $objectSid
        SchemaClassName = $SchemaClassName
        Parent          = $Parent
        Path            = $DirectoryPath
        SchemaEntry     = $SchemaEntry
        Properties      = $Properties
    }

    Add-Member -InputObject $Object -Name RefreshCache -MemberType ScriptMethod -Value {}
    Add-Member -InputObject $Object -Name Invoke -MemberType ScriptMethod -Value {}
    return $Object

}
