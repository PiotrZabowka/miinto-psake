$psakenet = @{
    config = @{
        solutionDir = $psake.build_script_dir
        test_results_dir = Join-Path $psake.build_script_dir ".build\TestResults"
        nunit_categories = ""
        nunit_exclude_categories = ""
        artifact_dir = Join-Path $psake.build_script_dir ".build\Output"
        package_dir = Join-Path $psake.build_script_dir ".build\Package"
        test_artifacts_dir = Join-Path $psake.build_script_dir ".build\Tests"
        config = "Release"
        output_dir_name = "bin"
    };
    importedTasks = @()
}
function LoadConfiguration {
    param(
        [string] $configdir = $psake.build_script_dir
    )

    $psakeConfigFilePath = (join-path $configdir "psakenet-config.ps1")

    if (test-path $psakeConfigFilePath -pathType Leaf) {
        try {
            $config = $psakenet.config
            . $psakeConfigFilePath
        } catch {
            throw "Error Loading Configuration from psakenet-config.ps1: " + $_
        }
    }
}
function Import-Tasks() { 
	param([Parameter(Mandatory=$true)][string[]]$tasks) 

	foreach($task in $tasks) { 
		$psakeNetTaskFile = Join-Path $psakenet.config.solutionDir ".build\tasks\$task.ps1"; 
		if (Test-Path $psakeNetTaskFile) { 

            if(!$psakenet.importedTasks.Contains($task)){
                Include $psakeNetTaskFile;
                $psakenet.importedTasks += $task 
            }
        } else { 
            Write-Host -ForegroundColor Red "Import-Tasks: cannot not find `\"$task`\""; 
            exit 1; 
        } 
	} 
}
function Assert-IsWebProject {
	param([string]$csproj)

	(((Select-String -pattern "<UseIISExpress>.+</UseIISExpress>" -path "$csproj") -ne $null) -and ((Select-String -pattern "<OutputType>WinExe</OutputType>" -path "$csproj") -eq $null))
}

function Assert-IsConsoleProject {
	param([string]$csproj)

	(((Select-String -pattern "<UseIISExpress>.+</UseIISExpress>" -path "$csproj") -eq $null) -and ((Select-String -pattern "<OutputType>Exe</OutputType>" -path "$csproj") -ne $null))
}

function Assert-IsLibraryProject {
	param([string]$csproj)

	(((Select-String -pattern "<UseIISExpress>.+</UseIISExpress>" -path "$csproj") -eq $null) -and ((Select-String -pattern "<OutputType>Library</OutputType>" -path "$csproj") -ne $null))
}
function New-Directory {
	param([string]$dir)

	if (-not (Test-Path "$dir")) { New-Item -ItemType Directory -Path "$dir" -Force | Out-Null }
}
function Remove-FileOrDirectory {
	param([string]$path)

	Remove-Item "$path" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}

function Get-NugetSettings {
    if (-not (Test-Path $psakenet.config.nuGetExe -PathType Leaf)) { 
        $PsakeNetNuGetDir = Split-Path $psakenet.config.nuGetExe; 
        New-Item -ItemType Directory -Path "$PsakeNetNuGetDir" -Force | Out-Null; 
        Write-Host 'Downloading NuGet.exe' -ForegroundColor Cyan; 
        $(New-Object System.Net.WebClient).DownloadFile('https://www.nuget.org/nuget.exe', $psakenet.config.nuGetExe); 
    } else { 
        Write-Host 'Updating NuGet.exe' -ForegroundColor Cyan; 
        cmd /c $psakenet.config.nuGetExe update -Self; 
    }; 

    $psakenet.config.packagesDir = (cmd /c $psakenet.config.nuGetExe config repositoryPath -AsPath); 
    if (-not (Test-Path $psakenet.config.packagesDir -PathType Container -IsValid)) { $psakenet.config.packagesDir = Join-Path $psakenet.config.solutionDir "packages" }; 
}
function Get-PackagesDir {
    $psakenet.config.packagesDir = (cmd /c $psakenet.config.nuGetExe config repositoryPath -AsPath); 
    if (-not (Test-Path $psakenet.config.packagesDir -PathType Container -IsValid)) { $psakenet.config.packagesDir = Join-Path $psakenet.config.solutionDir "packages" }; 
    $psakenet.config.packagesDir
}
function Get-NugetPackages {

    Write-Host "Restoring NuGet packages" -ForegroundColor Cyan; 
    & $psakenet.config.nuGetExe restore $(Join-Path $psakenet.config.solutionDir "$($psakenet.config.solutionName).sln") -PackagesDirectory $psakenet.config.packagesDir 
}

function Get-ValueOrDefault($value, $default) { 
    @{$true=$value;$false=$default}[$value -or $value -eq ''] 
} 

function Get-PackageDir() { 
	param([Parameter(Mandatory=$true)][string]$packageName); 

    $solutionPackagesConfig = Join-Path $psakenet.config.solutionDir ".nuget\packages.config"; 
    $defaultProjectPackagesConfig = Join-Path $psakenet.config.defaultProjectDir "packages.config"; 

    if (Test-Path $solutionPackagesConfig) { $packages += ([xml](Get-Content $solutionPackagesConfig)).packages.package; }; 
    if (Test-Path $defaultProjectPackagesConfig) { $packages += ([xml](Get-Content $defaultProjectPackagesConfig)).packages.package; }; 

    $numberOfPackagesFound = ($packages | Group id | Where { $_.Name -eq $packageName }).Count; 
    $packagesDir = Get-PackagesDir
    if ($numberOfPackagesFound -gt 1) { 
		Write-Host -ForegroundColor Red "ERROR: Found multiple versions of \"'$packageName'\" NuGet package installed in the solution"; 
		exit 1; 
    } elseif ($numberOfPackagesFound -eq 1) { 
        $package = $packages | Where { $_.id -eq $packageName }; 
        return Join-Path $packagesDir ($package.id + '.' + $package.version); 
    }; 

    $all_packages = Get-ChildItem $packagesDir | Where { $_.Name -match "$packageName.[0-9]+.*" }; 
	if ($all_packages -eq $null -or $all_packages.Count -eq 0) { 
		Write-Host -ForegroundColor Red "ERROR: Cannot find '$packageName' NuGet package"; 
		exit 1; 
	} elseif ($all_packages.Count -gt 1) { 
		Write-Host -ForegroundColor Red "ERROR: Found multiple versions of \"'$packageName'\" NuGet package in the packages directory"; 
		exit 1; 
	}; 

	return $all_packages[0].FullName; 
}

function Get-SemVer {
    $PsakeNetGitVersionExe = Join-Path (Get-PackageDir 'GitVersion.CommandLine') 'tools\GitVersion.exe'; 
    $PsakeNetGitVersion = Out-String -InputObject (cmd /c $PsakeNetGitVersionExe /nofetch /url $psakenet.config.gitRepo /u $psakenet.config.gitUser /p $psakenet.config.gitPassword /b $psakenet.config.gitBranch); 
    try { 
        return $(ConvertFrom-Json -InputObject $PsakeNetGitVersion).SemVer 
    } catch [System.Exception] { 
        Write-Host -ForegroundColor Red $PsakeNetGitVersion; exit 1 
    }; 

}

function Update-AssemblyVersion {
    Write-Host "Atempting to resolve semantic version" -ForegroundColor Cyan; 
    $PsakeNetGitVersionExe = Join-Path (Get-PackageDir 'GitVersion.CommandLine') 'tools\GitVersion.exe'; 
    cmd /c $PsakeNetGitVersionExe /output buildserver /updateassemblyinfo true /url $psakenet.config.gitRepo /u $psakenet.config.gitUser /p $psakenet.config.gitPassword /b $psakenet.config.gitBranch
}
function Get-TestProjectsFromSolution {
	$solution = "$(Join-Path $psakenet.config.solutionDir $psakenet.config.solutionName).sln"
	If(Test-Path "$solution") {
		$projects = @()
			Get-Content "$solution" |
			Select-String 'Project\(' |
				ForEach {
					$projectParts = $_ -Split '[,=]' | ForEach { $_.Trim('[ "{}]') };
					if($projectParts[2].EndsWith(".csproj") -and ($projectParts[1].EndsWith("Tests"))) {
						$projectPathParts = $projectParts[2].Split("\");
						$projects += New-Object PSObject -Property @{
							Name = $projectParts[1];
							File = $projectPathParts[-1];
							Directory = Join-Path $psakenet.config.solutionDir $projectParts[2].Replace("\$($projectPathParts[-1])", "");
							Type = switch($projectParts[1]) { {$_.EndsWith("UnitTests")} { "UnitTests" } {$_.EndsWith("IntegrationTests")} { "IntegrationTests" } {$_.EndsWith("AcceptanceTests")} { "AcceptanceTests" } };
						}
					}
				}
		return $projects
	}
}
function Get-TestAssembliesForTestFramework {
	param([PSCustomObject[]]$test_projects, [string]$test_framework_assembly)

	$test_assemblies = @()
	$test_artifacts_dir = $psakenet.config.test_artifacts_dir

	foreach ($test_project in $test_projects) {
		$test_project_artifact_dir = $( Join-Path $(Join-Path "$test_artifacts_dir" "$($test_project.Type)") "$($test_project.Name)")
		$test_project_assemblies_dir = @{$true=(Join-Path "$test_project_artifact_dir" "bin");$false=$test_project_artifact_dir}[(Test-Path (Join-Path "$test_project_artifact_dir" "bin"))]
			
		if (Test-Path "$(Join-Path "$test_project_assemblies_dir" $test_framework_assembly)") {
			$test_assemblies += Join-Path "$test_project_assemblies_dir" "$($test_project.Name).dll"
		}
	}

	return $test_assemblies
}

function Get-FrameworkVersion {
	($psake.context.Peek().config.framework -split "^((?:\d+\.\d+)(?:\.\d+){0,1})(x86|x64){0,1}$")[1]
}

function Invoke-Tests {
	param([PSCustomObject[]]$test_projects)
	
    if ($test_projects -eq $null -or $test_projects.Count -eq 0) { 
		Write-Host "No test projects were found"
		return
	}

	New-Directory $psakenet.config.test_results_dir
	
	Invoke-NUnitTests (Get-TestAssembliesForTestFramework $test_projects "nunit.framework.dll")
}

function Invoke-NUnitTests {
	param([PSCustomObject[]]$assemblies)

	if($assemblies.Count -gt 0) {	
		"`r`nRunning NUnit Tests"
		$nunit = Join-Path (Get-PackageDir "NUnit.ConsoleRunner") "tools\nunit3-console.exe"
		$framework_version = Get-FrameworkVersion

        $include = @{$true="cat==$($psakenet.config.nunit_categories.split(',') -Join "||cat==")";$false=""}[-not[String]::IsNullOrWhiteSpace($psakenet.config.nunit_categories)]
        $exclude = @{$true="cat!=$($psakenet.config.nunit_exclude_categories.split(',') -Join "&&cat!=")";$false=""}[-not[String]::IsNullOrWhiteSpace($psakenet.config.nunit_exclude_categories)]

		if ((-not[String]::IsNullOrWhiteSpace($include)) -and (-not[String]::IsNullOrWhiteSpace($exclude))) {
			$where = @("--where","($include)and($exclude)")
		} elseif ([String]::IsNullOrWhiteSpace($include) -and (-not[String]::IsNullOrWhiteSpace($exclude))) {
			$where = @("--where","$exclude")
		} elseif ((-not[String]::IsNullOrWhiteSpace($include)) -and [String]::IsNullOrWhiteSpace($exclude)) {
			$where = @("--where","$include")
		} else {
			$where = ""
		}

        exec { & $nunit --work $psakenet.config.test_results_dir --result "$(Join-Path $psakenet.config.test_results_dir 'NUnit.xml')" --framework "net-4.5" --teamcity $where --noheader $assemblies }
	
	}
}



LoadConfiguration

$psakenet.config.defaultProjectDir = Join-Path $psakenet.config.solutionDir $psakenet.config.defaultProject

export-modulemember -function Import-Tasks, New-Directory, Get-SemVer, Get-NugetSettings, Get-NugetPackages, Get-ValueOrDefault, Update-AssemblyVersion, Get-TestProjectsFromSolution, Invoke-Tests, Invoke-NUnitTests, Assert-IsWebProject, Assert-IsConsoleProject, Assert-IsLibraryProject, Remove-FileOrDirectory -variable psakenet