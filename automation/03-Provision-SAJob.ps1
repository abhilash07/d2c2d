﻿<#
.Synopsis 
    This PowerShell script provisions a Stream Analytics Job
.Description 
    This PowerShell script provisions a Stream Analytics Job
.Notes 
    File Name  : Provision-SAJob.ps1
    Author     : Ron Bokleman, Bob Familiar
    Requires   : PowerShell V4 or above, PowerShell / ISE Elevated

    Please do not forget to ensure you have the proper local PowerShell Execution Policy set:

        Example:  Set-ExecutionPolicy Unrestricted 

    NEED HELP?

    Get-Help .\Provision-SAJob.ps1 [Null], [-Full], [-Detailed], [-Examples]

.Link   
    https://github.com/bobfamiliar/d2c2d
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The storage account name.")]
    [string]$Subscription,
    [Parameter(Mandatory=$True, Position=1, HelpMessage="The resource group name.")]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$True, Position=2, HelpMessage="The Azure Service Bus Name Space.")]
    [string]$AzureLocation,
    [Parameter(Mandatory=$True, Position=3, HelpMessage="The prefix for naming standards.")]
    [string]$Prefix,
    [Parameter(Mandatory=$True, Position=4, HelpMessage="The suffix for naming standards.")]
    [string]$Suffix
)

##########################################################################################
# F U N C T I O N S
##########################################################################################

Function Select-Subscription()
{
    Param([String] $Subscription)

    Try
    {
        Select-AzureRmSubscription -SubscriptionName $Subscription -ErrorAction Stop
    }
    Catch
    {
        Write-Verbose -Message $Error[0].Exception.Message
        Write-Verbose -Message "Exiting due to exception: Subscription Not Selected."
    }
}

Function Create-SAJob-OutputToQueue()
{
    param (
    [string]$SAJobName,
    [string]$SAJobQuery,
    [string]$iothubshortname,
    [string]$IoTHubKeyName,
    [string]$IoTHubKey,
    [String]$AzureLocation, 
    [string]$SBNamespace, 
    [string]$SBQueueName, 
    [string]$SBPolicyName, 
    [string]$SBPolicyKey)

    $CreatedDate = Get-Date -Format u

    $JSON = @"
    {  
       "location":"$AzureLocation",
       "properties":{  
          "sku":{  
             "name":"standard"
          },
          "outputStartTime":"$CreatedDate",
          "outputStartMode":"CustomTime",
          "eventsOutOfOrderPolicy":"drop",
          "eventsOutOfOrderMaxDelayInSeconds":10,
          "inputs":[  
             {  
                "name":"iothub",
                "properties":{  
                   "type":"stream",
                   "serialization":{  
                      "type":"JSON",
                      "properties":{  
                         "encoding":"UTF8"
                      }
                   },
                   "datasource":{  
                      "type":"Microsoft.Devices/IotHubs",
                      "properties":{  
                        "iotHubNamespace": "$iothubshortname",
                        "sharedAccessPolicyKey": "$IotHubKey",
                        "sharedAccessPolicyName": "$IotHubKeyName"
                      }
                   }
                }
             }
          ],
          "transformation":{  
             "name":"$SAJobName",
             "properties":{  
                "streamingUnits":1,
                "query": "$SAJobQuery"
             }
          },
        "outputs": [
          {
            "name": "queue",
            "properties": {
              "type": "stream",
              "serialization": {
                "type": "JSON",
                "properties": {
                  "encoding": "UTF8"
                }
              },
              "datasource": {
                "type": "Microsoft.ServiceBus/Queue",
                "properties": {
                    "serviceBusNamespace":"$SBNameSpace",
                    "sharedAccessPolicyName":"$SBPolicyName",
                    "sharedAccessPolicyKey":"$SBPolicyKey",
                    "queueName":"$SBQueueName"
                }
              }
            }
          }
        ]
      }
  }
"@

    $Path = ".\SAJobs\$SAJobName.json"

    $JSON | Set-Content -Path $Path

    Start-Sleep -Seconds 10
    Return $Path
}

#######################################################################################
# S E T  P A T H
#######################################################################################

$Path = Split-Path -parent $PSCommandPath
$Path = Split-Path -parent $path

#######################################################################################
# V A R I A B L E S
#######################################################################################

$sbnamespace = $prefix + "sbname" + $suffix
$IoTHubKeyName = "iothubowner"
$sajobname = "d2c2d-send2queue"
$SAJobQuery = "select * into queue from iothub"
$iothubname = $prefix + "iothub" + $suffix

#######################################################################################
# M A I N
#######################################################################################

# Mark the start time.
$StartTime = Get-Date

$includePath = $Path + "\Automation\ConnectionStrings.ps1"
."$includePath"

$AzureSBNS = Get-AzureSBNamespace $sbnamespace

$Rule = Get-AzureSBAuthorizationRule -Namespace $sbnamespace 
$SBPolicyName = $Rule.Name
$SBPolicyKey = $Rule.Rule.PrimaryKey

$SAJobPath = Create-SAJob-OutputToQueue -SAJobName $sajobname -SAJobQuery $SAJobQuery -IoTHubShortName $IoTHubName -IoTHubKeyName $IoTHubKeyName -IoTHubKey $iothubkey -AzureLocation $AzureLocation -SBNamespace $sbnamespace -SBQueueName messagedrop -SBPolicyName $SBPolicyName -SBPolicyKey $SBPolicyKey
New-AzureRmStreamAnalyticsJob -ResourceGroupName $ResourceGroupName -Name $sajobname -File $SAJobPath -Force
Start-AzureRmStreamAnalyticsJob -ResourceGroupName $ResourceGroupName -Name $sajobname

# Mark the finish time.
$FinishTime = Get-Date

#Console output
$TotalTime = ($FinishTime - $StartTime).TotalSeconds
Write-Verbose -Message "Elapse Time (Seconds): $TotalTime" -Verbose
