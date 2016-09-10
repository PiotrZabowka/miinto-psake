Task Test -Description "Run all tests" {
	exec { Invoke-Tests (Get-TestProjectsFromSolution) }
}

Task UnitTest -Description "Run unit tests" {
    exec { Invoke-Tests (Get-TestProjectsFromSolution | Where-Object { $_.Type -eq "UnitTests" }) }
}

Task IntegrationTest -Description "Run integration tests" {
	exec { Invoke-Tests (Get-TestProjectsFromSolution | Where-Object { $_.Type -eq "IntegrationTests" }) }
}

Task AcceptanceTest -Description "Run acceptance tests" {
	exec { Invoke-Tests (Get-TestProjectsFromSolution | Where-Object { $_.Type -eq "AcceptanceTests" }) }
}