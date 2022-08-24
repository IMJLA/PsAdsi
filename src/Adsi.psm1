<#
# Add any custom C# classes as usable (exported) types
$CSharpFiles = Get-ChildItem -Path "$PSScriptRoot\*.cs"
ForEach ($ThisFile in $CSharpFiles) {
    Add-Type -Path $ThisFile.FullName -ErrorAction Stop
}
#>
Export-ModuleMember -Function @('Add-DomainFqdnToLdapPath','Add-SidInfo','ConvertFrom-DirectoryEntry','ConvertFrom-PropertyValueCollectionToString','ConvertTo-DecStringRepresentation','ConvertTo-DistinguishedName','ConvertTo-DomainNetBIOS','ConvertTo-DomainSidString','ConvertTo-Fqdn','ConvertTo-HexStringRepresentation','ConvertTo-HexStringRepresentationForLDAPFilterString','ConvertTo-SidByteArray','Expand-AdsiGroupMember','Expand-IdentityReference','Expand-WinNTGroupMember','Find-AdsiProvider','Get-AdsiGroup','Get-AdsiGroupMember','Get-AdsiServer','Get-CurrentDomain','Get-DirectoryEntry','Get-DomainInfo','Get-TrustedDomain','Get-TrustedDomainInfo','Get-WellKnownSid','Get-Win32Account','Get-WinNTGroupMember','Invoke-ComObject','New-FakeDirectoryEntry','Resolve-Ace','Resolve-Ace3','Resolve-Ace4','Resolve-IdentityReference','Search-Directory')


























