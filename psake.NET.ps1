param([string[]]$runTasks)

$ErrorActionPreference = 'Stop'; 
$MinPSMajorVersion = 3; 

if ($PSVersionTable.PSVersion.Major -lt $MinPSMajorVersion) { 
    Write-Host -ForegroundColor Red "ERROR: The script cannot be run because it requires Windows PowerShell version 3.0 or greater";
    exit 1 
} 

function Private:Get-ValueOrDefault($value, $default) { 
    @{$true=$value;$false=$default}[$value -or $value -eq ''] 
} 
function Private:Test-LastExitCode { 
    if ($LastExitCode -ne 0 -and $LastExitCode) { 
        Write-Host "ExitCode: $LastExitCode" -ForegroundColor Red; exit $LastExitCode 
    } 
} 

$PsakeNetBaseDir = Get-ValueOrDefault $env:PSAKE_NET_BASE_DIR $(Join-Path $PSScriptRoot '..'); 
$PsakeNetSolutionName = Get-ValueOrDefault $env:PSAKE_NET_SOLUTION_NAME (Get-ChildItem -Path $PsakeNetBaseDir *.sln | Select-Object -First 1).BaseName; 
$PsakeNetSolutionDir = Get-ValueOrDefault $env:PSAKE_NET_SOLUTION_DIR $PsakeNetBaseDir 
$PsakeNetDefaultProjectName = Get-ValueOrDefault $env:PSAKE_NET_DEFAULT_PROJECT_NAME $PsakeNetSolutionName 
$PsakeNetDefaultProjectDir = Get-ValueOrDefault $env:PSAKE_NET_DEFAULT_PROJECT_DIR $(Join-Path $PsakeNetBaseDir $PsakeNetDefaultProjectName) 

$PsakeNetNuGet = Get-ValueOrDefault $env:PSAKE_NET_NUGET $(Join-Path $PsakeNetSolutionDir '.nuget\NuGet.exe'); 
if (-not (Test-Path $PsakeNetNuGet -PathType Leaf)) { 
    $PsakeNetNuGetDir = Split-Path $PsakeNetNuGet; 
    New-Item -ItemType Directory -Path "$PsakeNetNuGetDir" -Force | Out-Null; 
	Write-Host 'Downloading NuGet.exe' -ForegroundColor Cyan; 
	$(New-Object System.Net.WebClient).DownloadFile('https://www.nuget.org/nuget.exe', $PsakeNetNuGet); 
} else { 
    Write-Host 'Updating NuGet.exe' -ForegroundColor Cyan; 
    cmd /c "$PsakeNetNuGet" update -Self; 
}; 

$PsakeNetPackagesDir = (cmd /c "$PsakeNetNuGet" config repositoryPath -AsPath); 
if (-not (Test-Path $PsakeNetPackagesDir -PathType Container -IsValid)) { $PsakeNetPackagesDir = Join-Path $PsakeNetBaseDir "packages" }; 

Write-Host "Restoring NuGet packages" -ForegroundColor Cyan; 
& $PsakeNetNuGet restore $(Join-Path $PsakeNetSolutionDir "$PsakeNetSolutionName.sln") -PackagesDirectory $PsakeNetPackagesDir 
Test-LastExitCode; 

function Get-PackageDir() { 
	param([Parameter(Mandatory=$true)][string]$packageName); 

    $solutionPackagesConfig = Join-Path "$PsakeNetSolutionDir" ".nuget\packages.config"; 
    $defaultProjectPackagesConfig = Join-Path "$PsakeNetDefaultProjectDir" "packages.config"; 

    if (Test-Path $solutionPackagesConfig) { $packages += ([xml](Get-Content $solutionPackagesConfig)).packages.package; }; 
    if (Test-Path $defaultProjectPackagesConfig) { $packages += ([xml](Get-Content $defaultProjectPackagesConfig)).packages.package; }; 

    $numberOfPackagesFound = ($packages | Group id | Where { $_.Name -eq $packageName }).Count; 

    if ($numberOfPackagesFound -gt 1) { 
		Write-Host -ForegroundColor Red "ERROR: Found multiple versions of \"'$packageName'\" NuGet package installed in the solution"; 
		exit 1; 
    } elseif ($numberOfPackagesFound -eq 1) { 
        $package = $packages | Where { $_.id -eq $packageName }; 
        return Join-Path $PsakeNetPackagesDir ($package.id + '.' + $package.version); 
    }; 

    $all_packages = Get-ChildItem $PsakeNetPackagesDir | Where { $_.Name -match "\$packageName.[0-9]+.*\" }; 
	if ($all_packages -eq $null -or $all_packages.Count -eq 0) { 
		Write-Host -ForegroundColor Red "ERROR: Cannot find \"'$packageName'\" NuGet package"; 
		exit 1; 
	} elseif ($all_packages.Count -gt 1) { 
		Write-Host -ForegroundColor Red "ERROR: Found multiple versions of \"'$packageName'\" NuGet package in the packages directory"; 
		exit 1; 
	}; 

	return $all_packages[0].FullName; 
}; 

Write-Host "Atempting to resolve semantic version" -ForegroundColor Cyan; 
$PsakeNetGitVersionExe = Join-Path (Get-PackageDir 'GitVersion.CommandLine') 'tools\GitVersion.exe'; 
$PsakeNetGitVersion = Out-String -InputObject (cmd /c $PsakeNetGitVersionExe /nofetch); 
try { 
    Write-Host "Semantic version: " $(ConvertFrom-Json -InputObject $PsakeNetGitVersion).SemVer 
} catch [System.Exception] { 
    Write-Host -ForegroundColor Red $PsakeNetGitVersion; exit 1 
}; 
Test-LastExitCode; 

$PsakeModule = Join-Path (Get-PackageDir 'psake') 'tools\psake.psm1'; 
$PsakeNetDir = Join-Path $PsakeNetBaseDir 'psake.NET'; 
$PsakeNetFunctions = Join-Path $PsakeNetDir 'Functions.ps1'; 
if (-not (Test-Path $PsakeNetFunctions -PathType Leaf)) { 
	$PsakeNetDir = Get-PackageDir 'psake.NET'; 
	$PsakeNetFunctions = Join-Path $PsakeNetDir 'Functions.ps1'; 
}; 

function Import-Tasks() { 
	param([Parameter(Mandatory=$true)][string[]]$tasks) 

	foreach($task in $tasks) { 
		$psakeNetTaskFile = Join-Path "$PsakeNetDir" "tasks\$task.ps1"; 
		if (Test-Path $psakeNetTaskFile) { 
            Include $psakeNetTaskFile; 
        } else { 
            Write-Host -ForegroundColor Red "Import-Tasks: cannot not find `\"$task`\""; 
            exit 1; 
        } 
	} 

    $customTasksDir = Join-Path "$PsakeNetBaseDir" ".build\tasks"; 
    if (Test-Path $customTasksDir) { 
        Get-ChildItem $customTasksDir | Foreach { Include $_.FullName }; 
    }; 
}; 

function Import-Properties() { 
    Include "$PsakeNetFunctions"; 
	Properties { . $(Join-Path "$PsakeNetDir" "Properties.ps1"); }; 
}

Import-Module "$PsakeModule"; 
Write-Host 'Invoking psake' -ForegroundColor Cyan; 
Invoke-psake $(Join-Path $PsakeNetBaseDir 'tasks.ps1') $runTasks

if (($psake.build_success -eq $false) -and ($LastExitCode -eq 0 -or -not ($LastExitCode))) { $LastExitCode = 1 }; 
Test-LastExitCode;