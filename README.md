# ConfigureVseSubscription

Scripts for configuring a fresh Visual Studio Enterprise (MPN) subscription.


[Naming standard](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)

Region: North Europe

1. Create Resource Group

[hashtable] $ResourceGroup = @{
    Name = 'rg-vseautomation-001'
    Location = 'North Europe'
}

2. Create Automation Account

