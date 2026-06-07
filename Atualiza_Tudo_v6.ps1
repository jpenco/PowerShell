```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================
# CONFIGURAÇÕES
# ============================
$TimeoutSeconds = 600   # 10 minutos por etapa
$global:cancelExecution = $false

# ============================
# GUI
# ============================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Pipeline de Atualizações - Windows 11"
$form.Size = New-Object System.Drawing.Size(650,520)
$form.StartPosition = "CenterScreen"
$form.Topmost = $false

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Size = New-Object System.Drawing.Size(600,260)
$logBox.Location = New-Object System.Drawing.Point(10,10)
$form.Controls.Add($logBox)

function Write-Log {
    param([string]$msg)

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("`r`n[$timestamp] $msg")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# ============================
# CHECKBOXES
# ============================
$chkWinUpdate = New-Object System.Windows.Forms.CheckBox
$chkWinUpdate.Text = "Windows Update"
$chkWinUpdate.Location = New-Object System.Drawing.Point(10,280)
$chkWinUpdate.Checked = $true
$form.Controls.Add($chkWinUpdate)

$chkDrivers = New-Object System.Windows.Forms.CheckBox
$chkDrivers.Text = "Drivers (Microsoft Update)"
$chkDrivers.Location = New-Object System.Drawing.Point(10,310)
$form.Controls.Add($chkDrivers)

$chkStore = New-Object System.Windows.Forms.CheckBox
$chkStore.Text = "Aplicativos da Microsoft Store"
$chkStore.Location = New-Object System.Drawing.Point(10,340)
$chkStore.Checked = $true
$form.Controls.Add($chkStore)

$chkWinget = New-Object System.Windows.Forms.CheckBox
$chkWinget.Text = "Programas via Winget"
$chkWinget.Location = New-Object System.Drawing.Point(10,370)
$chkWinget.Checked = $true
$form.Controls.Add($chkWinget)

# ============================
# PROGRESS BAR
# ============================
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,410)
$progressBar.Size = New-Object System.Drawing.Size(600,20)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# ============================
# BOTÕES
# ============================

# Fechar App
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Fechar App"
$btnClose.Size = New-Object System.Drawing.Size(150,40)
$btnClose.Location = New-Object System.Drawing.Point(20,440)
$form.Controls.Add($btnClose)

# Executar Pipeline
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Executar Pipeline"
$btnStart.Size = New-Object System.Drawing.Size(150,40)
$btnStart.Location = New-Object System.Drawing.Point(200,440)
$form.Controls.Add($btnStart)

# Cancelar
$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Size = New-Object System.Drawing.Size(150,40)
$btnCancel.Location = New-Object System.Drawing.Point(380,440)
$form.Controls.Add($btnCancel)

$btnCancel.Add_Click({
    $global:cancelExecution = $true
    Write-Log "⚠ Cancelamento solicitado pelo usuário."
})

$btnClose.Add_Click({

    $global:cancelExecution = $true

    Write-Log "Encerrando aplicação..."

    Start-Sleep -Milliseconds 300

    try {
        $form.Close()
    } catch {}

    [System.Windows.Forms.Application]::Exit()

    Stop-Process -Id $PID -Force
})

# ============================
# EXECUÇÃO DE ETAPAS
# ============================
function Run-IsolatedStep {

    param(
        [string]$Name,
        [scriptblock]$Code,
        [int]$StepIndex,
        [int]$TotalSteps
    )

    if ($global:cancelExecution) {
        Write-Log "⚠ Execução cancelada antes de iniciar $Name."
        return
    }

    Write-Log "▶ Iniciando: $Name..."

    if ($TotalSteps -gt 0) {
        $progressBar.Value = [Math]::Min(
            [int](($StepIndex / $TotalSteps) * 100),
            100
        )
    }

    $pool = [RunspaceFactory]::CreateRunspacePool(1,1)
    $pool.Open()

    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool

    [void]$ps.AddScript($Code)

    $handle = $ps.BeginInvoke()

    $elapsed = 0

    while (-not $handle.IsCompleted) {

        Start-Sleep -Milliseconds 500
        $elapsed += 0.5

        [System.Windows.Forms.Application]::DoEvents()

        if ($global:cancelExecution) {

            try {
                $ps.Stop()
            } catch {}

            Write-Log "⚠ $Name cancelado."
            return
        }

        if ($elapsed -ge $TimeoutSeconds) {

            try {
                $ps.Stop()
            } catch {}

            Write-Log "⏳ Timeout em $Name (limite de $TimeoutSeconds segundos)."
            return
        }
    }

    try {

        $result = $ps.EndInvoke($handle)

        if ($result -eq $true) {
            Write-Log "✅ $Name concluído. Atualizações aplicadas."
        }
        else {
            Write-Log "ℹ $Name concluído. Nenhuma atualização encontrada."
        }
    }
    catch {

        Write-Log ("❌ Erro em {0}: {1}" -f $Name, $_)
    }
    finally {

        try { $ps.Dispose() } catch {}
        try { $pool.Close() } catch {}
        try { $pool.Dispose() } catch {}
    }
}

# ============================
# PIPELINE
# ============================
$btnStart.Add_Click({

    $global:cancelExecution = $false

    $progressBar.Value = 0

    Write-Log "===================================="
    Write-Log "PIPELINE INICIADO"
    Write-Log "===================================="

    $steps = @()

    if ($chkWinUpdate.Checked) {

        $steps += @{
            Name = "Windows Update"
            Code = {

                Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

                $updates = Install-WindowsUpdate `
                    -AcceptAll `
                    -IgnoreReboot `
                    -ErrorAction SilentlyContinue

                return ($updates.Count -gt 0)
            }
        }
    }

    if ($chkDrivers.Checked) {

        $steps += @{
            Name = "Drivers (Microsoft Update)"
            Code = {

                Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

                $drivers = Get-WindowsUpdate `
                    -MicrosoftUpdate `
                    -AcceptAll `
                    -Install `
                    -ErrorAction SilentlyContinue

                return ($drivers.Count -gt 0)
            }
        }
    }

    if ($chkStore.Checked) {

        $steps += @{
            Name = "Microsoft Store"
            Code = {

                Start-Process "ms-windows-store://downloadsandupdates"

                return $true
            }
        }
    }

    if ($chkWinget.Checked) {

        $steps += @{
            Name = "Winget"
            Code = {

                $output = winget upgrade `
                    --all `
                    --silent `
                    --accept-package-agreements `
                    --accept-source-agreements

                return (
                    ($output -match "Upgraded") -or
                    ($output -match "Atualizado")
                )
            }
        }
    }

    $total = $steps.Count

    if ($total -eq 0) {

        Write-Log "⚠ Nenhuma opção foi selecionada."

        return
    }

    $index = 0

    foreach ($step in $steps) {

        $index++

        Run-IsolatedStep `
            -Name $step.Name `
            -Code $step.Code `
            -StepIndex $index `
            -TotalSteps $total

        if ($global:cancelExecution) {
            break
        }
    }

    if ($global:cancelExecution) {

        Write-Log "⚠ PIPELINE CANCELADO."
    }
    else {

        $progressBar.Value = 100

        Write-Log "===================================="
        Write-Log "PIPELINE FINALIZADO"
        Write-Log "===================================="
    }
})

# ============================
# FECHAR PELO X DA JANELA
# ============================
$form.Add_FormClosing({

    $global:cancelExecution = $true
})

# ============================
# EXIBIR FORMULÁRIO
# ============================
[void]$form.ShowDialog()
```
