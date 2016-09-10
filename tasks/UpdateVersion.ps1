Import-Tasks NuGet

Task UpdateVersion -Depends NuGetSettings {
    Update-AssemblyVersion
}