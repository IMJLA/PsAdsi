function ConvertFrom-AppCapabilitySid {
    <#
# https://devblogs.microsoft.com/oldnewthing/20220503-00/?p=106557
SIDs of the form S-1-15-3-xxx are app capability SIDs.
These SIDs are present in the token of apps running in an app container, and they encode the app capabilities possessed by the app.
The rules for Mandatory Integrity Control say that objects default to allowing write access only to medium integrity level (IL) or higher.
Granting access to these app capability SIDs permit access from apps running at low IL, provided they possess the matching capability.

Autogenerated
S-1-15-3-x1-x2-x3-x4	device capability
S-1-15-3-1024-x1-x2-x3-x4-x5-x6-x7-x8	app capability

You can sort of see how these assignments evolved.
At first, the capability RIDs were assigned by an assigned numbers authority, so anybody who wanted a capability had to apply for a number.
After about a dozen of these, the assigned numbers team (probably just one person) realized that this had the potential to become a real bottleneck, so they switched to an autogeneration mechanism, so that people who needed a capability SID could just generate their own.
For device capabilities, the four 32-bit decimal digits represent the 16 bytes of the device interface GUID.
Let’s decode this one: S-1-15-3-787448254-1207972858-3558633622-1059886964.

787448254	1207972858	3558633622	1059886964 # Starting format is four 32-bit decimal numbers
0x2eef81be	0x480033fa	0xd41c7096	0x3f2c9774 # Convert each number to hexadeximal.
be 81 ef 2e	fa 33 00 48	96 70 1c d4	74 97 2c 3f # Split each number into 4 bytes then reverse. WHY?
2eef81be	33fa 4800	96 70 1c d4	74 97 2c 3f
{2eef81be-	33fa-4800-	96 70-1c d4 74 97 2c 3f}

And we recognize {2eef81be-33fa-4800-9670-1cd474972c3f} as DEVINTERFACE_AUDIO_CAPTURE, so this is the microphone device capability.
For app capabilities, the eight 32-bit decimal numbers represent the 32 bytes of the SHA256 hash of the capability name.
You can programmatically generate these app capability SIDs by calling Derive­Capability­Sids­From­Name.
#>

    param (
        #[string]$SID = 'S-1-15-3-1024-3035980445-2343077072-2039973919-2593655016-2336600711-3402322490-2613491542-1611519126'
        [string]$SID = 'S-1-15-3-787448254-1207972858-3558633622-1059886964'
    )

    $KnownDeviceInterfaceGuids = @{
        'BFA794E4-F964-4FDB-90F6-51056BFE4B44' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Location Services access {BFA794E4-F964-4FDB-90F6-51056BFE4B44}'
            'Name'            = 'Location Services device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Location services'
        }
        'E5323777-F976-4f5b-9B55-B94699C46E44' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Camera access {E5323777-F976-4f5b-9B55-B94699C46E44}'
            'Name'            = 'Camera device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your camera'
        }
        '2EEF81BE-33FA-4800-9670-1CD474972C3F' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Microphone access {2EEF81BE-33FA-4800-9670-1CD474972C3F}'
            'Name'            = 'Audio Capture Interface device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your microphone'
        }
        '52079E78-A92B-413F-B213-E8FE35712E72' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Notifications access {52079E78-A92B-413F-B213-E8FE35712E72}'
            'Name'            = 'Notifications device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your notifications'
        }
        'C1D23ACC-752B-43E5-8448-8D0E519CD6D6' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Account Information access (name, picture, etc.) {C1D23ACC-752B-43E5-8448-8D0E519CD6D6}'
            'Name'            = 'Account Information device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your account information'
        }
        '7D7E8402-7C54-4821-A34E-AEEFD62DED93' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Contacts access {7D7E8402-7C54-4821-A34E-AEEFD62DED93}'
            'Name'            = 'Contacts device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your contacts'
        }
        'D89823BA-7180-4B81-B50C-7E471E6121A3' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Calendar access {D89823BA-7180-4B81-B50C-7E471E6121A3}'
            'Name'            = 'Calendar device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your calendar'
        }
        '8BC668CF-7728-45BD-93F8-CF2B3B41D7AB' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Call History access {8BC668CF-7728-45BD-93F8-CF2B3B41D7AB}'
            'Name'            = 'Call History device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your call history'
        }
        '9231CB4C-BF57-4AF3-8C55-FDA7BFCC04C5' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with access to read and send Email {9231CB4C-BF57-4AF3-8C55-FDA7BFCC04C5}'
            'Name'            = 'Email device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Email'
        }
        '21157C1F-2651-4CC1-90CA-1F28B02263F6' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with access to read and send SMS and MMS messages {21157C1F-2651-4CC1-90CA-1F28B02263F6}'
            'Name'            = 'SMS Interface device capability' #c_media.inf
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Messages (text or MMS)'
        }
        'A8804298-2D5F-42E3-9531-9C8C39EB29CE' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with access to control radios {A8804298-2D5F-42E3-9531-9C8C39EB29CE}'
            'Name'            = 'Radio Control device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Radio control'
        }
        '9D9E0118-1807-4F2E-96E4-2CE57142E196' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Activity Sensor access {9D9E0118-1807-4F2E-96E4-2CE57142E196}'
            'Name'            = 'Activity Sensor device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your activity sensors'
        } #c_sensor.inf
        'B19F89AF-E3EB-444B-8DEA-202575A71599' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with access to unknown capability {B19F89AF-E3EB-444B-8DEA-202575A71599}'
            'Name'            = 'Unknown device capability from SettingsHandlers_Privacy.dll'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\B19F89AF-E3EB-444B-8DEA-202575A71599'
        } #SettingsHandlers_Privacy.dll
        'E6AD100E-5F4E-44CD-BE0F-2265D88D14F5' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with access to unknown capability {E6AD100E-5F4E-44CD-BE0F-2265D88D14F5}'
            'Name'            = 'Unknown device capability from LocationPermissions.dll'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\E6AD100E-5F4E-44CD-BE0F-2265D88D14F5'
        } #LocationPermissions.dll
        'E83AF229-8640-4D18-A213-E22675EBB2C3' = @{
            'SID'             = $SID
            'SchemaClassName' = 'group'
            'Description'     = 'Apps with Custom Sensor access {E83AF229-8640-4D18-A213-E22675EBB2C3}'
            'Name'            = 'Custom Sensor device capability'
            'NTAccount'       = 'APPLICATION PACKAGE AUTHORITY\Your custom sensors'
        } #c_sensor.inf
    }

    $SidWithoutAuthorities = $SID.Replace('S-1-5-3-', '')

    switch ($SID.Split('-').Count) {
        8 { $CountOf32BitNumbers = 4 ; break } # Autogenerated device capability
        13 { return @{ 'SID' = $SID } } # Autogenerated app capability which cannot be translated.
        default { return @{ 'SID' = $SID } } # NO MATCH
    }
    $Substring = $SID
    $i = 0
    $ReversedDecimal = do {
        $Last = $Substring.LastIndexOf('-')
        $Substring.Substring($Last + 1, $Substring.Length - $Last - 1)
        $Substring = $Substring.Substring(0, $Last) ; $i++
    } while ($i -lt $CountOf32BitNumbers)
    $Bytes = For ($n = ($ReversedDecimal.Length - 1); $n -ge 0 ; $n = $n - 1 ) {
        $ThisNumber = $ReversedDecimal[$n]
        for ( $i = 3; $i -ge 0; $i-- ) {
            '{0:X2}' -f ($ThisNumber -band 0xff) #ugly and hard to read
            #[convert]::tostring(($ThisNumber -band 0xff), 16) # does not add leading zeroes
            $ThisNumber = $ThisNumber -shr 8
        }
    }

    $Guid = $Bytes[3], $Bytes[2], $Bytes[1], $Bytes[0], '-', $Bytes[5], $Bytes[4], '-', $Bytes[7], $Bytes[6], '-', $Bytes[8], $Bytes[9], '-', $($Bytes[10..15] -join '') -join ''

    $KnownGuid = $KnownDeviceInterfaceGuids[$Guid]
    if ($KnownGuid) {
        return $KnownGuid
    } else {
        return @{
            'SID'             = $SID
            'Description'     = "Apps with access to unknown capability {$Guid}"
            'Name'            = "Unknown device capability {$Guid}"
            'SchemaClassName' = 'group'
            'NTAccount'       = "APPLICATION PACKAGE AUTHORITY\$Guid"
        }
    }
}
