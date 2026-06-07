Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Threading

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

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Size = New-Object System.Drawing.Size(600,260)
$logBox.Location = New-Object System.Drawing.Point(10,10)
$form.Controls.Add($logBox)

function Write-Log($msg) {
    $logBox.AppendText("`r`n[$(Get-Date -Format 'HH:mm:ss')] $msg")
}

# Checkboxes
$chkWinUpdate = New-Object System.Windows.Forms.CheckBox
$chkWinUpdate.Text = "Windows Update"
$chkWinUpdate.Location = New-Object System.Drawing.Point(10,280)
$chkWinUpdate.Checked = $true
$form.Controls.Add($chkWinUpdate)

$chkDrivers = New-Object System.Windows.Forms.CheckBox
$chkDrivers.Text = "Drivers (Microsoft Update)"
$chkDrivers.Location = New-Object System.Drawing.Point(10,310)
$chkDrivers.Checked = $false
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

# ProgressBar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10,410)
$progressBar.Size = New-Object System.Drawing.Size(600,20)
$form.Controls.Add($progressBar)

# Botões
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Executar Pipeline"
$btnStart.Size = New-Object System.Drawing.Size(150,40)
$btnStart.Location = New-Object System.Drawing.Point(200,440)
$form.Controls.Add($btnStart)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Size = New-Object System.Drawing.Size(150,40)
$btnCancel.Location = New-Object System.Drawing.Point(370,440)
$form.Controls.Add($btnCancel)

$btnCancel.Add_Click({
    $global:cancelExecution = $true
    Write-Log "⚠ Cancelamento solicitado pelo usuário."
})

# ============================
# EXECUÇÃO EM RUNSPACE
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
    $progressBar.Value = [Math]::Min(($StepIndex / $TotalSteps) * 100,100)

    # Criar runspace isolado
    $pool = [runspacefactory]::CreateRunspacePool(1,1)
    $pool.Open()
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    $ps.AddScript($Code)

    $handle = $ps.BeginInvoke()

    $elapsed = 0
    while (-not $handle.IsCompleted) {
        Start-Sleep -Milliseconds 500
        $elapsed += 0.5

        if ($global:cancelExecution) {
            $ps.Stop()
            Write-Log "⚠ $Name cancelado."
            return
        }

        if ($elapsed -ge $TimeoutSeconds) {
            $ps.Stop()
            Write-Log "⏳ Timeout em $Name (limite de $TimeoutSeconds segundos)."
            return
        }
    }

    $result = $ps.EndInvoke($handle)
    $ps.Dispose()
    $pool.Close()

    if ($result -eq $true) {
        Write-Log "✅ $Name concluído. Atualizações aplicadas."
    } else {
        Write-Log "ℹ $Name concluído. Nenhuma atualização encontrada."
    }
}

# ============================
# PIPELINE
# ============================
$btnStart.Add_Click({
    $global:cancelExecution = $false
    Write-Log "===== PIPELINE INICIADO ====="

    $steps = @()

    if ($chkWinUpdate.Checked) {
        $steps += @{Name="Windows Update"; Code={
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            $u = Install-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction SilentlyContinue
            return ($u.Count -gt 0)
        }}
    }

    if ($chkDrivers.Checked) {
        $steps += @{Name="Drivers (Microsoft Update)"; Code={
            Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue
            $d = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -ErrorAction SilentlyContinue
            return ($d.Count -gt 0)
        }}
    }

    if ($chkStore.Checked) {
        $steps += @{Name="Microsoft Store"; Code={
            Start-Process "ms-windows-store://downloadsandupdates"
            return $true
        }}
    }

    if ($chkWinget.Checked) {
        $steps += @{Name="Winget"; Code={
            $out = winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
            return ($out -match "Upgraded" -or $out -match "Atualizado")
        }}
    }

    $total = $steps.Count
    $i = 0

    foreach ($s in $steps) {
        $i++
        Run-IsolatedStep -Name $s.Name -Code $s.Code -StepIndex $i -TotalSteps $total
        if ($global:cancelExecution) { break }
    }

    $progressBar.Value = 100
    Write-Log "===== PIPELINE FINALIZADO ====="
})

$form.ShowDialog()
