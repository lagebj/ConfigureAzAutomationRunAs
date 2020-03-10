#Requires -RunAsAdministrator

Param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $Location
)


[hashtable] $ResourceGroup = @{
    Name = $ResourceGroupName
    Location = $Location
}

New-AzResourceGroup @ResourceGroup