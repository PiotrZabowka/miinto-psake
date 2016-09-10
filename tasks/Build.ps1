Task Build -Description "Build the solution; create a Octopus Deploy package or zip artifact if required" {
	$sln = "$(Join-Path $psakenet.config.solutionDir "$($psakenet.config.solutionName).sln")"
	$csproj = "$(Join-Path $psakenet.config.defaultProjectDir "$($psakenet.config.defaultProject).csproj")"
	$artifact_dir = $psakenet.config.artifact_dir
	$config = $psakenet.config.config
	$output_dir_name = Join-Path $psakenet.config.output_dir_name $config
	$test_artifacts_dir = $psakenet.config.test_artifacts_dir
    $remove_artifact_pdb = $psakenet.config.remove_artifact_pdb
	Assert (Test-Path "$sln") "Cannot not find solution '$sln'"
	Assert (Test-Path "$csproj") "Cannot find project '$csproj'"

	if (Assert-IsWebProject $csproj) {
		Write-Host "Building '$($psakenet.config.solutionName)' solution`r`n"
		exec { msbuild "$sln" /t:Build /p:Configuration=$config /p:Platform="Any Cpu" /p:WebProjectOutputDir="$output_dir_name" /p:OutDir="$(Join-Path "$output_dir_name" "bin\")" /verbosity:quiet }
	}
	elseif (Assert-IsConsoleProject $csproj) {
		Write-Host "Building '$($psakenet.config.solutionName)' solution`r`n"
		exec { msbuild "$sln" /t:Build /p:Configuration=$config /p:Platform="Any Cpu" /p:OutputPath="$output_dir_name" /verbosity:quiet }
	}
	elseif (Assert-IsLibraryProject $csproj) {
		Write-Host "Building '$($psakenet.config.solutionName)' solution`r`n"
		exec { msbuild "$sln" /t:Build /p:Configuration=$config /p:Platform="Any Cpu" /p:OutputPath="$output_dir_name" /verbosity:quiet }
	}
	else {
		Write-Host -ForegroundColor Red "Could not build '$($psakenet.config.solutionName)'; unable to identify project type"
		exit 1
	}
	
	# Artifact default project
	$project_build_output_dir = $(Join-Path $psakenet.config.defaultProjectDir "$output_dir_name")
	Copy-Item "$project_build_output_dir" "$artifact_dir" -Recurse -Force
	
	if ($remove_artifact_pdb -eq $true) {
		# Remove program database files from the project's artifact
		Remove-FileOrDirectory "$(Join-Path "$artifact_dir" "**\*.pdb")"
	}

	# Artifact tests
    $test_projects = Get-TestProjectsFromSolution
	foreach ($test_project in $test_projects) {
		$test_project_artifact_dir = $( Join-Path $(Join-Path "$test_artifacts_dir" "$($test_project.Type)") "$($test_project.Name)")
		$test_build_output_dir = $(Join-Path "$($test_project.Directory)" "$output_dir_name")
		Copy-Item "$test_build_output_dir" "$test_project_artifact_dir" -Recurse -Force
	}
}