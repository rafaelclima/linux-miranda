
<h1 align="center">🚀 Guia Rápido de Instalação e Configuração - Anduin OS Miranda</h1>

Este guia vai te ajudar a instalar e configurar o **Anduin OS**, ou outra distribuição linux baseada em debian, com o navegador Sankhya e alguns outros softwares essenciais.   
Siga na ordem que não tem erro! 😉

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/3/35/Tux.svg" alt="Linux Logo" width="200" style="margin-right: 140px;"/>
  <img src="https://lh3.googleusercontent.com/d/1gVGI0GgiIywENstJnNwp_kqD1DG3kNfv" alt="Logo Miranda" width="240"/>
</p>

---

## 🗂️ 1) Instalação do Navegador Sankhya

### 📁 Crie uma pasta "Navegador_Sankhya" na raiz do /home

```bash
cd ~/
mkdir Navegador_Sankhya
```

### 🌐 Baixe o Navegador Sankhya

Acesse o site oficial da **Sankhya** e faça o download do Navegador.
[Página de download do navegador Sankhya](https://downloads.sankhya.com.br/)

### 📦 Extraia e Copie

Extraia o conteúdo do arquivo baixado e copie tudo para a pasta `Navegador_Sankhya` criada anteriormente.
OBS: Copie o conteúdo inteiro de dentro da pasta e não a pasta que foi extraída.

### 🔒 Dê Permissão de Execução

```bash
chmod +x ~/Navegador_Sankhya/execNavegadorSankhya
```

### 🖱️ Crie o Atalho do Navegador Sankhya

```bash
nano ~/.local/share/applications/navegador-sankhya.desktop
```

Cole o conteúdo abaixo (troque `SEU_USUARIO` pelo usuário que você criou para a máquina em questão):

```ini
[Desktop Entry]
Name=Navegador Sankhya
Comment=Navegador Sankhya
Exec=bash -c "cd /home/SEU_USUARIO/Navegador_Sankhya && ./execNavegadorSankhya"
Icon=/home/SEU_USUARIO/Navegador_Sankhya/resources/icon.png
Terminal=false
Type=Application
StartupNotify=true
Categories=WebBrowser
```

✅ **Salve e feche o arquivo.** (no nano o atalho para salvar é CTRL + O, confirma e depois CTRL + X para sair). O atalho aparecerá no menu do sistema!

---

## 🔗 2) Configuração do Serviço Web Connection

### 🛠️ Instale o java

```bash
sudo apt install default-jdk
```

### 🛠️ Crie o Serviço do WebConnection

```bash
sudo nano /etc/systemd/system/web-connection.service
```

Cole o conteúdo a baixo no arquivo criado anteriormente (troque `SEU_USUARIO` pelo usuário que você criou para a máquina em questão):

```ini
[Unit]
Description=Serviço de Conexão Sankhya WebConnection
After=network.target

[Service]
User=SEU_USUARIO
ExecStart=/usr/bin/java -jar /home/SEU_USUARIO/Navegador_Sankhya/resources/app/webConnection/web-connection-webclient-plugin.jar
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=web-connection-plugin

[Install]
WantedBy=multi-user.target
```

### 🔄 Recarregue o SystemD

```bash
sudo systemctl daemon-reload
```

### ▶️ Inicie o Serviço

```bash
sudo systemctl start web-connection.service
```

### 🔍 Verifique o Status

```bash
sudo systemctl status web-connection.service
```

---

## 💻 3) Programas Extras

✅ **OnlyOffice:** Instale pela loja de aplicativos do sistema.

✅ **Definições da Impressora:** Instale pela loja.

🔗 **TeamViewer Host:**  
[Download TeamViewer Host](https://download.teamviewer.com/download/linux/teamviewer-host_amd64.deb)

Para instalar:
✅ Para instalar o TeamViewer Host, basta apenas dar 2 cliques no arquivo baixado que a loja será aberta e a instalação ocorrerá por lá.

🖨️ **Driver para Impressoras HP:**

```bash
sudo apt install hplip
```

---

## 🎉 Tudo Pronto!

Parabéns! Seu ambiente está pronto para uso. 🚀  
Em caso de dúvidas, chame o **TI**! 👨‍💻✨
