Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Criar Formulário
$form = New-Object System.Windows.Forms.Form
$form.Text = "Pipeline de Atualizações - Windows 11"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.StartPosition = "CenterScreen"

# Caixa de texto para log
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Size = New-Object System.Drawing.Size(560,250)
$logBox.Location = New-Object System.Drawing.Point(10,10)
$form.Controls.Add($logBox)

# Botão de execução
$button = New-Object System.Windows.Forms.Button
$button.Text = "Executar Pipeline"
$button.Size = New-Object System.Drawing.Size(200,40)
$button.Location = New-Object System.Drawing.Point(200,280)
$form.Controls.Add($button)

# Função para log
function Write-Log($msg) {
    $logBox.AppendText("`r`n[$(Get-Date -Format 'HH:mm:ss')] $msg")
}

# Função genérica de pipeline
function Run-Step($stepName, $action) {
    Write-Log "▶ Iniciando: $stepName..."
    try {
        $result = & $action
        if ($result) {
            Write-Log "✅ ${stepName} concluído. Atualizações aplicadas."
        } else {
            Write-Log "ℹ ${stepName} concluído. Nenhuma atualização encontrada."
        }
    } catch {
        Write-Log ("❌ Erro em " + $stepName + ": " + $_.Exception.Message)
    }
}

# Ação do botão
$button.Add_Click({
    Write-Log "===== PIPELINE DE ATUALIZAÇÕES INICIADO ====="

    # Etapa 1 - Windows Update
    Run-Step "Windows Update" {
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            $updates = Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
            return ($updates.Count -gt 0)
        } catch {
            Write-Log "Módulo PSWindowsUpdate não encontrado. Instale com: Install-Module PSWindowsUpdate -Force"
            return $false
        }
    }

    # Etapa 2 - Drivers
    Run-Step "Drivers (Microsoft Update)" {
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            $drivers = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install
            return ($drivers.Count -gt 0)
        } catch {
            Write-Log "Não foi possível atualizar drivers (PSWindowsUpdate ausente)."
            return $false
        }
    }

    # Etapa 3 - Microsoft Store
    Run-Step "Aplicativos da Microsoft Store" {
        try {
            Start-Process "ms-windows-store://downloadsandupdates"
            Write-Log "➡ A Store foi aberta na tela de atualizações."
            return $true
        } catch {
            return $false
        }
    }

    # Etapa 4 - Winget
    Run-Step "Programas via Winget" {
        try {
            $output = winget upgrade --all
            return ($output -match "Atualizado" -or $output -match "Upgraded")
        } catch {
            Write-Log "Winget não encontrado."
            return $false
        }
    }

    Write-Log "===== PIPELINE FINALIZADO ====="
    [System.Windows.Forms.MessageBox]::Show("Pipeline concluído! Verifique o log para detalhes.","Status")
})

# Exibir GUI
$form.ShowDialog()
