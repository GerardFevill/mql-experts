# Module CloudWatch pour les scripts d'initialisation
# Ce module fournit des fonctions pour installer et configurer l'agent CloudWatch

# Installation et configuration de l'agent CloudWatch
function Install-CloudWatchAgent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$CloudWatchFolder = "C:\CloudWatch",
        
        [Parameter(Mandatory = $false)]
        [string]$LogGroupName = "/ec2/mt5-instance"
    )
    
    try {
        # Créer le dossier pour l'agent CloudWatch
        New-Item -Path $CloudWatchFolder -ItemType Directory -Force | Out-Null
        Write-Log -Message "Dossier $CloudWatchFolder créé." -LogFile $LogFilePath
        
        # Télécharger l'agent CloudWatch
        $cloudWatchAgentUrl = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
        $cloudWatchAgentMsi = "$CloudWatchFolder\amazon-cloudwatch-agent.msi"
        
        Write-Log -Message "Téléchargement de l'agent CloudWatch..." -LogFile $LogFilePath
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $cloudWatchAgentUrl -OutFile $cloudWatchAgentMsi
        Write-Log -Message "Agent CloudWatch téléchargé." -LogFile $LogFilePath
        
        # Vérifier que le fichier existe
        if (-not (Test-Path $cloudWatchAgentMsi)) {
            throw "Le fichier d'installation de l'agent CloudWatch n'a pas été téléchargé correctement."
        }
        
        # Installer l'agent CloudWatch
        Write-Log -Message "Installation de l'agent CloudWatch..." -LogFile $LogFilePath
        $installProcess = Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$cloudWatchAgentMsi`" /qn" -Wait -PassThru
        
        if ($installProcess.ExitCode -ne 0) {
            throw "L'installation de l'agent CloudWatch a échoué avec le code d'erreur $($installProcess.ExitCode)."
        }
        
        Write-Log -Message "Agent CloudWatch installé." -LogFile $LogFilePath
        
        # Configurer l'agent CloudWatch
        $cloudWatchConfig = Get-CloudWatchConfig -LogGroupName $LogGroupName -LogFilePath $LogFilePath
        $cloudWatchConfigPath = "$CloudWatchFolder\config.json"
        $cloudWatchConfig | Out-File -FilePath $cloudWatchConfigPath -Encoding ascii
        Write-Log -Message "Configuration de l'agent CloudWatch créée." -LogFile $LogFilePath
        
        # Démarrer l'agent CloudWatch
        Write-Log -Message "Démarrage de l'agent CloudWatch..." -LogFile $LogFilePath
        $cwAgentCtl = "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"
        
        if (Test-Path $cwAgentCtl) {
            & $cwAgentCtl -a fetch-config -m ec2 -s -c file:$cloudWatchConfigPath
            Write-Log -Message "Agent CloudWatch démarré." -LogFile $LogFilePath
        } else {
            throw "Le fichier de contrôle de l'agent CloudWatch n'a pas été trouvé."
        }
        
        return $true
    } 
    catch {
        Write-Log -Message "ERREUR lors de l'installation de l'agent CloudWatch: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Fonction pour générer la configuration CloudWatch
function Get-CloudWatchConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogGroupName,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        # Configuration de base pour l'agent CloudWatch
        $config = @{
            agent = @{
                metrics_collection_interval = 60
                logfile = "c:\CloudWatch\logs\amazon-cloudwatch-agent.log"
            }
            logs = @{
                logs_collected = @{
                    files = @{
                        collect_list = @(
                            @{
                                file_path = $LogFilePath
                                log_group_name = $LogGroupName
                                log_stream_name = "init-script"
                                timestamp_format = "%Y-%m-%d %H:%M:%S"
                            },
                            @{
                                file_path = "C:\Windows\Temp\user_data_execution.log"
                                log_group_name = $LogGroupName
                                log_stream_name = "user-data"
                                timestamp_format = "%Y-%m-%d %H:%M:%S"
                            },
                            @{
                                file_path = "C:\MT5\logs\*.log"
                                log_group_name = $LogGroupName
                                log_stream_name = "metatrader"
                                timestamp_format = "%Y-%m-%d %H:%M:%S"
                            }
                        )
                    }
                    windows_events = @{
                        collect_list = @(
                            @{
                                event_name = "System"
                                event_levels = @("ERROR", "WARNING", "CRITICAL")
                                log_group_name = $LogGroupName
                                log_stream_name = "system-events"
                            },
                            @{
                                event_name = "Application"
                                event_levels = @("ERROR", "WARNING", "CRITICAL")
                                log_group_name = $LogGroupName
                                log_stream_name = "application-events"
                            }
                        )
                    }
                }
            }
            metrics = @{
                metrics_collected = @{
                    cpu = @{
                        resources = @("*")
                        measurement = @(
                            "% Idle Time",
                            "% Interrupt Time",
                            "% User Time",
                            "% Processor Time"
                        )
                        aggregation_dimensions = @( @() )
                    }
                    memory = @{
                        measurement = @(
                            "% Committed Bytes In Use",
                            "Available Bytes",
                            "Cache Faults/sec",
                            "Page Faults/sec",
                            "Pages/sec"
                        )
                        aggregation_dimensions = @( @() )
                    }
                    disk = @{
                        resources = @("*")
                        measurement = @(
                            "% Idle Time",
                            "% Disk Time",
                            "% Disk Read Time",
                            "% Disk Write Time",
                            "% User Time",
                            "Disk Write Bytes/sec",
                            "Disk Read Bytes/sec",
                            "Disk Transfers/sec"
                        )
                        aggregation_dimensions = @( @() )
                    }
                }
                append_dimensions = @{
                    InstanceId = "${aws:InstanceId}"
                }
            }
        }
        
        # Convertir en JSON
        $jsonConfig = $config | ConvertTo-Json -Depth 10
        
        return $jsonConfig
    }
    catch {
        Write-Log -Message "ERREUR lors de la génération de la configuration CloudWatch: $_" -LogFile $LogFilePath -IsError
        throw
    }
}

# Exporter les fonctions du module
Export-ModuleMember -Function Install-CloudWatchAgent, Get-CloudWatchConfig
