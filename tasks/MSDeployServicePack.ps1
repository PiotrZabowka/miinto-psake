Task MSDeployServicePack {
    New-Directory $psakenet.config.package_dir
    $msdeployExe = Join-Path $psakenet.config.MSDeployPath msdeploy.exe
    $semVer = Get-SemVer
    $paramsConfigFile = (join-path $psakenet.config.solutionDir "params-config.ps1")

    if (test-path $paramsConfigFile -pathType Leaf) {
        try {
            . $paramsConfigFile
        } catch {
            throw "Error Loading Params Config from params-config.ps1: " + $_
        }
    } 
    CreateConfigurationFiles $psakenet.config.solutionDir
    & "$msdeployExe" -verb:sync -source:contentPath=$($psakenet.config.artifact_dir) -dest:package=$(Join-Path $psakenet.config.package_dir "$($psakenet.config.defaultProject).$semVer.zip") -declareParamFile="$(Join-Path $psakenet.config.defaultProjectDir parameters.xml)" 
    Copy-Item $(Join-Path $psakenet.config.defaultProjectDir "SetParameters.*.xml") $psakenet.config.package_dir
}