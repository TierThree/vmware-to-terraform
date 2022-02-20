# vmware-to-terraform
Scripts for converting VMware infrastructure to Terraform with powershell on Linux

*Note: This requires some intial setup with the powershell on Linux, described below.*

## Installing PowerShell on Linux
Start by adding the key and repo:
```
curl https://packages.microsoft.com/keys/microsoft.asc > MS.key
apt-key add MS.key
curl https://packages.microsoft.com/config/$(cat /etc/*ease | grep ^ID= | awk -F= '{print $2}')/$(cat /etc/*ease | grep VERSION_ID= | awk -F\" '{print $2}')/prod.list | sudo tee /etc/apt/sources.list.d/microsoft.list
```

Now update and install powershell
```
sudo apt update && sudo apt install powershell -y
```

## Installing PowerCLI on Linux
If not already, you may need to add powershell to your path. Once done, do the following:
```
pwsh
Install-Module -Name VMware.PowerCLI
Import-Module VMware.PowerCLI
```

To test if this worked, do the following:
```
Get-VICommand
```

## Using the Script
COMING SOON
