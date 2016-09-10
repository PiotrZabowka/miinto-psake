Task Clean -Description "Delete all intermediate and build output files" {
	$artifact_dir = $psakenet.config.artifact_dir
	$test_artifacts_dir = $psakenet.config.test_artifacts_dir
	$test_results_dir = $psakenet.config.test_results_dir
	$package_dir = $psakenet.config.package_dir
	$solution_dir = $psakenet.config.solutionDir
    
	if (Test-Path $artifact_dir) {
		Write-Host "Cleaning '$artifact_dir'"
		Remove-FileOrDirectory "$(Join-Path "$artifact_dir" "*")"
	}
	if (Test-Path $test_artifacts_dir) {
		Write-Host "Cleaning '$test_artifacts_dir'"
		Remove-FileOrDirectory "$(Join-Path "$test_artifacts_dir" "*")"
	}
	if (Test-Path $test_results_dir) {
		Write-Host "Cleaning '$test_results_dir'"
		Remove-FileOrDirectory "$(Join-Path "$test_results_dir" "*")"
	}
	if (Test-Path $package_dir) {
		Write-Host "Cleaning '$package_dir'"
		Remove-FileOrDirectory "$(Join-Path "$package_dir" "*")"
	}
	Write-Host "Cleaning '$solution_dir'"
	Remove-FileOrDirectory "$(Join-Path "$solution_dir" "*\bin")"
	Remove-FileOrDirectory "$(Join-Path "$solution_dir" "*\obj")"
}