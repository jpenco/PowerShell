Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Criar Formulário
$form = New-Object System.Windows.Forms.Form
$form.Text = "Atualizador do Windows 11"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.StartPosition = "CenterScreen"

# Caixa de texto para log
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.Size = New-Object System.Drawing.Size(560,250)
$logBox.Location = New-Object System.Drawing.Point(10,10)
$form.Controls.Add($logBox)

# Botão de atualização
$button = New-Object System.Windows.Forms.Button
$button.Text = "Iniciar Atualizações"
$button.Size = New-Object System.Drawing.Size(200,40)
$button.Location = New-Object System.Drawing.Point(200,280)
$form.Controls.Add($button)

# Função para log
function Write-Log($msg) {
    $logBox.AppendText("`r`n[$(Get-Date -Format 'HH:mm:ss')] $msg")
}

# Ação do botão
$button.Add_Click({
    Write-Log "Iniciando processo de atualização..."

    # Atualizar Windows Update
    Write-Log "Verificando atualizações do Windows..."
    try {
        Import-Module PSWindowsUpdate -ErrorAction Stop
        Install-WindowsUpdate -AcceptAll -IgnoreReboot | Out-Null
        Write-Log "Atualizações do Windows concluídas."
    } catch {
        Write-Log "❌ Erro: módulo PSWindowsUpdate não encontrado."
        Write-Log "➡ Instale com: Install-Module PSWindowsUpdate -Force"
    }

    # Atualizar Drivers via Windows Update
    Write-Log "Atualizando drivers..."
    try {
        Import-Module PSWindowsUpdate -ErrorAction Stop
        Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install | Out-Null
        Write-Log "Drivers atualizados."
    } catch {
        Write-Log "❌ Não foi possível atualizar drivers (PSWindowsUpdate ausente)."
    }

    # Atualizar Apps da Microsoft Store
    Write-Log "Atualizando aplicativos da Microsoft Store..."
    try {
        Start-Process "ms-windows-store://downloadsandupdates"
        Write-Log "➡ A Store foi aberta na tela de atualizações."
    } catch {
        Write-Log "❌ Não foi possível abrir a Microsoft Store."
    }

    # Atualizar programas via Winget
    Write-Log "Atualizando programas instalados via Winget..."
    try {
        winget upgrade --all --silent | Out-Null
        Write-Log "Programas atualizados."
    } catch {
        Write-Log "❌ Winget não encontrado. Instale via Microsoft Store ou atualize o Windows."
    }

    # Status final
    Write-Log "✅ Todas as atualizações foram concluídas (ou sinalizadas)."
    [System.Windows.Forms.MessageBox]::Show("Processo de atualização finalizado! Verifique o log para detalhes.","Status")
})

# Exibir GUI
$form.ShowDialog()
