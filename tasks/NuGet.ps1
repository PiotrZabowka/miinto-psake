Task NuGetSettings -Description "Loads NuGet settings" {
    Get-NugetSettings 
}

Task NuGet -Depends NuGetSettings -Description "Downloads nuget packages" {
    Get-NugetPackages 
}
