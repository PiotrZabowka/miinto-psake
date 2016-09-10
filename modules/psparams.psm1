$psparams = @{
    configurationItems = @{};
    environments = @{};
    roles = @{};
    servers = @{};
    env = @{};
    server = @{};
    role = @{};
}
function extend($htold, $htnew)
{
    $keys = $htold.getenumerator() | foreach-object {$_.key}
    $keys | foreach-object {
        $key = $_
        if ($htnew.containskey($key))
        {
            $htold.remove($key)
        }
    }
    $htold = $htold + $htnew
    return $htold
}
function Environment {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$name,
        [Parameter(Position=1,Mandatory=1)][scriptblock]$properties
    )
    if($psparams.environments.ContainsKey($name)){
        $psparams.environments[$name] += $properties
    }else{
        $sb = { @{
           name=$name
        } }
        $psparams.environments.add($name,@($sb.GetNewClosure(),$properties))
    }
}

function Role {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$name,
        [Parameter(Position=1,Mandatory=1)][scriptblock]$properties
    )
    if($psparams.roles.ContainsKey($name)){
        $psparams.roles[$name] += $properties
    }else{
        $sb = { @{
           name=$name
        } }
        $psparams.roles.add($name,@($sb.GetNewClosure(),$properties))
    }
}

function Server {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$name,
        [Parameter(Position=1,Mandatory=1)][array]$environments,
        [Parameter(Position=2,Mandatory=1)][array]$roles,
        [Parameter(Position=3,Mandatory=1)][scriptblock]$properties
    )
    if($psparams.servers.ContainsKey($name)){
        $psparams.servers[$name] += $properties
    }else{
        $sb = { @{
           name = $name
           environments = $environments
           roles = $roles
        } }
        $psparams.servers.add($name,@($sb.GetNewClosure(),$properties))
    }
}

function Add-XPathParameter {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$name,
        [Parameter(Position=1,Mandatory=1)][string]$match,
        [Parameter(Mandatory=0)][string]$scope = "\.config$",
        [Parameter(Mandatory=0)][string]$kind = "XmlFile"
    )
    $parameterEntry = @{ kind = $kind; scope = $scope; match = $match }
    if(!$psparams.configurationItems.ContainsKey($name)){
        $psparams.configurationItems.add($name,@())
    }
    $psparams.configurationItems[$name] += $parameterEntry
}
function Add-ConnectionStringParameter {
   [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$name,
        [Parameter(Position=1,Mandatory=0)][string]$key = $name,
        [Parameter(Mandatory=0)][string]$scope = "\.config$"
    ) 
    Add-XPathParameter $name "//connectionStrings/add[@name='$key']/@value" -scope $scope
}
function Add-AppSettingsParameter {
   [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$name,
        [Parameter(Position=1,Mandatory=0)][string]$key = $name,
        [Parameter(Mandatory=0)][string]$scope = "\.config$"
    ) 
    Add-XPathParameter $name "//appSettings/add[@key='$key']/@value" -scope $scope
}
function Add-ApplicationSettingsParameter {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$name,
        [Parameter(Position=1,Mandatory=1)][string]$section,
        [Parameter(Position=2,Mandatory=0)][string]$key = $name,
        [Parameter(Mandatory=0)][string]$scope = "\.config$"
    ) 
    Add-XPathParameter $name "//applicationSettings/$section/setting[@name='$key']/value/text()" -scope $scope
}

function CreateSetParametersFile {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$filePath,
        [Parameter(Position=1,Mandatory=1)][hashtable]$role
    ) 
    $XmlWriter = New-Object System.XMl.XmlTextWriter($filePath,$Null)
 
    # Set The Formatting
    $xmlWriter.Formatting = "Indented"
    $xmlWriter.Indentation = "4"
 
    # Write the XML Decleration
    $xmlWriter.WriteStartDocument()
 
    # Write Root Element
    $xmlWriter.WriteStartElement("parameters")
 
    foreach($parameter in $psparams.configurationItems.GetEnumerator()) {
        # Write the Document
        $xmlWriter.WriteStartElement("setParameter")
        $xmlWriter.WriteAttributeString("name", $parameter.Name)
        $xmlWriter.WriteAttributeString("value", $role[$parameter.Name])
        $xmlWriter.WriteEndElement() # <-- Closing parameter
    }
 
    # Write Close Tag for Root Element
    $xmlWriter.WriteEndElement() # <-- Closing RootElement
 
    # End the XML Document
    $xmlWriter.WriteEndDocument()
 
    # Finish The Document
    $xmlWriter.Finalize
    $xmlWriter.Flush()
    $xmlWriter.Close()    
}

function CreateParemetersFile {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$filePath
    ) 
    $XmlWriter = New-Object System.XMl.XmlTextWriter($filePath,$Null)
 
    # Set The Formatting
    $xmlWriter.Formatting = "Indented"
    $xmlWriter.Indentation = "4"
 
    # Write the XML Decleration
    $xmlWriter.WriteStartDocument()
 
    # Write Root Element
    $xmlWriter.WriteStartElement("parameters")
 
    foreach($parameter in $psparams.configurationItems.GetEnumerator()){

        # Write the Document
        $xmlWriter.WriteStartElement("parameter")
        $xmlWriter.WriteAttributeString("name",$parameter.Name)
        foreach($entry in $parameter.Value){
            $xmlWriter.WriteStartElement("parameterEntry")
            $xmlWriter.WriteAttributeString("kind",$entry.kind)
            $xmlWriter.WriteAttributeString("scope",$entry.scope)
            $xmlWriter.WriteAttributeString("match",$entry.match)
            $xmlWriter.WriteEndElement() # <-- Closing parameterEntry
        }
        $xmlWriter.WriteEndElement() # <-- Closing parameter
    }
 
    # Write Close Tag for Root Element
    $xmlWriter.WriteEndElement() # <-- Closing RootElement
 
    # End the XML Document
    $xmlWriter.WriteEndDocument()
 
    # Finish The Document
    $xmlWriter.Finalize
    $xmlWriter.Flush()
    $xmlWriter.Close()
}
function CreateConfigurationFiles {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][string]$filePath
    ) 
    
    foreach ($envItem in $psparams.environments.GetEnumerator()) {
        $env = $psparams.env = @{}    
        foreach ($propertyBlock in $envItem.Value) {
            $e1 = . $propertyBlock
            $env = extend $env $e1
            $psparams.env = $env
        }
        foreach ($roleItem in $psparams.roles.GetEnumerator()) {
            $role = $psparams.role = @{}
            foreach ($propertyBlock in $roleItem.Value) {
                $r1 = . $propertyBlock
                $role = extend $role $r1
                $psparams.role = $role
        }
            CreateSetParametersFile (Join-Path $filePath "$($roleItem.Name)\\SetParameters.$($envItem.Name).xml") $psparams.role
        }
    }

    foreach ($role in $psparams.roles.GetEnumerator()) {
        CreateParemetersFile (Join-Path $filePath "$($role.Name)\\parameters.xml")
    }

}
export-modulemember -function Add-XPathParameter, Add-ConnectionStringParameter, Add-AppSettingsParameter, Add-ApplicationSettingsParameter, CreateConfigurationFiles, Environment, Role, Server -variable psparams
