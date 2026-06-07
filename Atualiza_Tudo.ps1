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
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot | Out-Null
    Write-Log "Atualizações do Windows concluídas."

    # Atualizar Drivers via Windows Update
    Write-Log "Atualizando drivers..."
    Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install | Out-Null
    Write-Log "Drivers atualizados."

    # Atualizar Apps da Microsoft Store
    Write-Log "Atualizando aplicativos da Microsoft Store..."
    Start-Process "ms-windows-store://downloadsandupdates"
    Write-Log "A atualização da Store foi iniciada (abra a Store para confirmar)."

    # Atualizar programas via Winget
    Write-Log "Atualizando programas instalados via Winget..."
    winget upgrade --all --silent | Out-Null
    Write-Log "Programas atualizados."

    # Status final
    Write-Log "✅ Todas as atualizações foram concluídas!"
    [System.Windows.Forms.MessageBox]::Show("Processo de atualização finalizado com sucesso!","Status")
})

# Exibir GUI
$form.ShowDialog()
