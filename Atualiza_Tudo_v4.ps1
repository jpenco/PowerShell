Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Criar Formulário
$form = New-Object System.Windows.Forms.Form
$form.Text = "Pipeline de Atualizações - Windows 11"
$form.Size = New-Object System.Drawing.Size(650,500)
$form.StartPosition = "CenterScreen"

# Caixa de texto para log
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Size = New-Object System.Drawing.Size(600,250)
$logBox.Location = New-Object System.Drawing.Point(10,10)
$form.Controls.Add($logBox)

# Checkboxes para seleção
$chkWinUpdate = New-Object System.Windows.Forms.CheckBox
$chkWinUpdate.Text = "Windows Update"
$chkWinUpdate.Location = New-Object System.Drawing.Point(10,270)
$chkWinUpdate.Checked = $true
$form.Controls.Add($chkWinUpdate)

$chkDrivers = New-Object System.Windows.Forms.CheckBox
$chkDrivers.Text = "Drivers (Microsoft Update)"
$chkDrivers.Location = New-Object System.Drawing.Point(10,300)
$chkDrivers.Checked = $true
$form.Controls.Add($chkDrivers)

$chkStore = New-Object System.Windows.Forms.CheckBox
$chkStore.Text = "Aplicativos da Microsoft Store"
$chkStore.Location = New-Object System.Drawing.Point(10,330)
$chkStore.Checked = $true
$form.Controls.Add($chkStore)

$chkWinget = New-Object System.Windows.Forms.CheckBox
$chkWinget.Text = "Programas via Winget"
$chkWinget.Location = New-Object System.Drawing.Point(10,360)
$chkWinget.Checked = $true
$form.Controls.Add($chkWinget)

# Barra de progresso
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,400)
$progressBar.Size = New-Object System.Drawing.Size(600,20)
$form.Controls.Add($progressBar)

# Botões
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Executar Pipeline"
$btnStart.Size = New-Object System.Drawing.Size(150,40)
$btnStart.Location = New-Object System.Drawing.Point(200,430)
$form.Controls.Add($btnStart)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Size = New-Object System.Drawing.Size(150,40)
$btnCancel.Location = New-Object System.Drawing.Point(370,430)
$form.Controls.Add($btnCancel)

# Variável de cancelamento
$global:cancelExecution = $false

# Função para log
function Write-Log($msg) {
    $logBox.AppendText("`r`n[$(Get-Date -Format 'HH:mm:ss')] $msg")
}

# Função genérica de pipeline
function Run-Step($stepName, $action, $stepIndex, $totalSteps) {
    if ($global:cancelExecution) {
        Write-Log "⚠ Execução cancelada antes de $stepName."
        return $false
    }

    $progressBar.Value = [Math]::Min(($stepIndex / $totalSteps) * 100,100)
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

# Ação do botão Cancelar
$btnCancel.Add_Click({
    $global:cancelExecution = $true
    Write-Log "⚠ Cancelamento solicitado pelo usuário."
})

# Ação do botão Start
$btnStart.Add_Click({
    $global:cancelExecution = $false
    Write-Log "===== PIPELINE DE ATUALIZAÇÕES INICIADO ====="

    $steps = @()
    if ($chkWinUpdate.Checked) { $steps += @{Name="Windows Update"; Action={
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            $updates = Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot
            return ($updates.Count -gt 0)
        } catch {
            Write-Log "Módulo PSWindowsUpdate não encontrado. Instale com: Install-Module PSWindowsUpdate -Force"
            return $false
        }
    }}}
    if ($chkDrivers.Checked) { $steps += @{Name="Drivers (Microsoft Update)"; Action={
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            $drivers = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install
            return ($drivers.Count -gt 0)
        } catch {
            Write-Log "Não foi possível atualizar drivers (PSWindowsUpdate ausente)."
            return $false
        }
    }}}
    if ($chkStore.Checked) { $steps += @{Name="Aplicativos da Microsoft Store"; Action={
        try {
            Start-Process "ms-windows-store://downloadsandupdates"
            Write-Log "➡ A Store foi aberta na tela de atualizações."
            return $true
        } catch {
            return $false
        }
    }}}
    if ($chkWinget.Checked) { $steps += @{Name="Programas via Winget"; Action={
        try {
            $output = winget upgrade --all
            return ($output -match "Atualizado" -or $output -match "Upgraded")
        } catch {
            Write-Log "Winget não encontrado."
            return $false
        }
    }}}

    $totalSteps = $steps.Count
    $stepIndex = 0

    foreach ($step in $steps) {
        $stepIndex++
        Run-Step $step.Name $step.Action $stepIndex $totalSteps
        if ($global:cancelExecution) { break }
    }

    $progressBar.Value = 100
    Write-Log "===== PIPELINE FINALIZADO ====="
    [System.Windows.Forms.MessageBox]::Show("Pipeline concluído! Verifique o log para detalhes.","Status")
})

# Exibir GUI
$form.ShowDialog()
