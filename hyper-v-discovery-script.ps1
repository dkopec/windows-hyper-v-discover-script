<#
.SYNOPSIS
    Collects information about Hyper-V clusters, hosts, and VMs, and exports the data to a specified format (JSON or CSV).

.DESCRIPTION
    This script collects a list of Hyper-V clusters, hosts in those clusters, and VMs on those hosts, along with the details of the VMs.
    If no clusters are found or the cluster service is not running, it collects information from the local Hyper-V host.
    The collected data is then exported to a specified format (JSON or CSV) in a specified directory.

.PARAMETER Output
    The path where the report will be saved. Defaults to the current directory.

.PARAMETER Format
    The format of the report. Valid values are "json" and "csv". Defaults to "json".

.EXAMPLE
    .\hyper-v-discovery-script.ps1 -Path "C:\Reports" -Format "csv"
    This command collects Hyper-V information and exports the report to a CSV file in the C:\Reports directory.

.EXAMPLE
    .\hyper-v-discovery-script.ps1 -Format "json"
    This command collects Hyper-V information and exports the report to a JSON file in the current directory.

.NOTES
    Author: Dominik Kopec <kopec.dominik@gmail.com>
    Date: 2024-09-04
    Version: 1.0
#>

param (
  [string]$Path = (Get-Location).Path,
  [ValidateSet("json", "csv")]
  [string]$Format = "json"
)

function Test-IsAdmin {
  $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if the user is an administrator
if (-not (Test-IsAdmin)) {
  Write-Error "This script requires administrative privileges. Please run the script as an administrator."
  exit
}

# Import the necessary modules
Import-Module FailoverClusters
Import-Module Hyper-V

# Get the current date and time
$currentDateTime = Get-Date -Format "yyyyMMdd_HHmmss"
$Filename = "HyperV_Report_$currentDateTime"

# Initialize arrays to hold the data
$vm_data = [System.Collections.ArrayList]::new()
$host_data = [System.Collections.ArrayList]::new()
$cluster_data = [System.Collections.ArrayList]::new()

# Try to get the list of clusters
try {
  $clusters = Get-Cluster -ErrorAction Stop
  $clustersFound = $true
}
catch {
  Write-Warning "Cluster service is not running or no clusters found. Collecting information from the local Hyper-V host."
  $clustersFound = $false
}

if (-not $clustersFound) {
  # Get the local Hyper-V host name
  $localHost = $env:COMPUTERNAME

  # Get the list of VMs on the local host
  $vms = Get-VM -ComputerName $localHost

  foreach ($vm in $vms) {
    $vmDetails = @{}
    $vmDetails.Add("ClusterName", "Local Node")
    $vmDetails.Add("Host", $localHost)
    $vm | Get-Member | Where-Object -Property MemberType -EQ "Property" | ForEach-Object {
      $vmDetails.Add("VM_$($_.Name)", ($vm | Select-Object -ExpandProperty $_.Name))
    }

    # Add the VM details to the data array
    $vm_data.Add($vmDetails) | Out-Null
  }

  # Get local host properties and Hyper-V settings
  $hostDetails = @{}
  $osDetails = Get-CimInstance -ClassName Win32_OperatingSystem
  $systemDetails = Get-CimInstance -ClassName Win32_ComputerSystem
  $hostDetails.Add("HostName", $localHost)
  $hyperVDetails = Get-VMHost
  $hyperVDetails | Get-Member | Where-Object -Property MemberType -EQ "Property" | ForEach-Object {
    $hostDetails.Add("HyperV_$($_.Name)", ($hyperVDetails | Select-Object -ExpandProperty $_.Name))
  }
  $osDetails | Get-Member | Where-Object -Property MemberType -EQ "Property" | ForEach-Object {
    $hostDetails.Add("OS_$($_.Name)", ($osDetails | Select-Object -ExpandProperty $_.Name))
  }
  $systemDetails | Get-Member | Where-Object -Property MemberType -EQ "Property" | ForEach-Object {
    $hostDetails.Add("System_$($_.Name)", ($systemDetails | Select-Object -ExpandProperty $_.Name))
  }

  # Add the host details to the data array
  $host_data.Add($hostDetails) | Out-Null
}
else {
  foreach ($cluster in $clusters) {
    # Add the cluster details to the data array
    $cluster_data.Add($cluster) | Out-Null

    # Get the list of hosts in the cluster
    $hosts = Get-ClusterNode -Cluster $cluster

    # ignore jscpd
    foreach ($host in $hosts) {
      # Get the list of VMs on the host
      $vms = Get-VM -ComputerName $host.Name

      foreach ($vm in $vms) {
        $vm | Add-Member -MemberType NoteProperty -Name "ClusterName" -Value $cluster.Name
        $vm | Add-Member -MemberType NoteProperty -Name "Host" -Value $host.Name

        # Add the VM details to the data array
        $vm_data.Add($vm) | Out-Null

      }

      # Get host properties and Hyper-V settings
      $hostDetails = @{}
      $osDetails = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $host.Name
      $systemDetails = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $host.Name
      $hostDetails.Add("HostName", $localHost)
      $hyperVDetails = Get-VMHost -ComputerName $host.Name
      $hyperVDetails | Get-Member | Where-Object -Property MemberType -EQ "Property" | ForEach-Object {
        $hostDetails.Add("HyperV_$($_.Name)", ($hyperVDetails | Select-Object -ExpandProperty $_.Name))
      }
      $osDetails | Get-Member | Where-Object -Property MemberType -EQ "Property" | ForEach-Object {
        $hostDetails.Add("OS_$($_.Name)", ($osDetails | Select-Object -ExpandProperty $_.Name))
      }
      $systemDetails | Get-Member | Where-Object -Property MemberType -EQ "Property" | ForEach-Object {
        $hostDetails.Add("System_$($_.Name)", ($systemDetails | Select-Object -ExpandProperty $_.Name))
      }

      # Add the host details to the data array
      $host_data.Add($hostDetails) | Out-Null
    }
  }
}

if ($Format -eq "json") {
  # Define the output file paths with the current date and time
  $outputJsonFile = Join-Path -Path $Path -ChildPath "$Filename.json"
  # Convert the data to JSON and export to a file
  $data = @{
    Clusters = $cluster_data
    Hosts    = $host_data
    VMs      = $vm_data
  }
  $json = $data | ConvertTo-Json -Compress
  # Use WriteAllLines to avoid the adding of BOM
  [IO.File]::WriteAllLines($outputJsonFile, $json)
  Write-Output "Report generated and saved to $outputJsonFile"
}
elseif ($Format -eq "csv") {
  # Export the data to separate CSV files
  $clusterCsvFile = Join-Path -Path $Path -ChildPath "$Filename-Clusters.csv"
  $hostCsvFile = Join-Path -Path $Path -ChildPath "$Filename-Hosts.csv"
  $vmCsvFile = Join-Path -Path $Path -ChildPath "$Filename-VMs.csv"

  $cluster_data | ForEach-Object { [PSCustomObject]$_ } | Export-Csv -Path $clusterCsvFile -NoTypeInformation
  $host_data | ForEach-Object { [PSCustomObject]$_ } | Export-Csv -Path $hostCsvFile -NoTypeInformation
  $vm_data | ForEach-Object { [PSCustomObject]$_ } | Export-Csv -Path $vmCsvFile -NoTypeInformation

  Write-Host "Report generated and saved to $clusterCsvFile, $hostCsvFile, and $vmCsvFile"
}
else {
  Write-Host "Invalid format specified. Please enter 'json' or 'csv'."
}
