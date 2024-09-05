# windows-hyper-v-discover-script

A Powershell script that looks up and exports Hyper-V details to json or csv.

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
