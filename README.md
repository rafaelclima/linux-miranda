
<h1 align="center">🚀 Guia Rápido de Instalação e Configuração - Anduin OS Miranda</h1>

Este guia vai te ajudar a instalar e configurar o **Anduin OS**, ou outra distribuição linux baseada em debian, com o navegador Sankhya e alguns outros softwares essenciais.   
Siga na ordem que não tem erro! 😉

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/3/35/Tux.svg" alt="Linux Logo" width="200" style="margin-right: 140px;"/>
  <img src="https://lh3.googleusercontent.com/d/1gVGI0GgiIywENstJnNwp_kqD1DG3kNfv" alt="Logo Miranda" width="240"/>
</p>

---

## 🗂️ 1) Instalação do Navegador Sankhya

### 📁 Crie uma pasta "Navegador_Sankhya" dentro de /opt

```bash
mkdir /opt/Navegador_Sankhya
```

### 🌐 Baixe o Navegador Sankhya

Acesse o site oficial da **Sankhya** e faça o download do Navegador.
[Página de download do navegador Sankhya](https://downloads.sankhya.com.br/)

### 📦 Extraia e Copie

Extraia o conteúdo do arquivo baixado e copie tudo para a pasta `Navegador_Sankhya` criada anteriormente.
OBS: Copie o conteúdo inteiro de dentro da pasta e não a pasta que foi extraída.

```bash
sudo cp -r diretorio_do_arquivo_baixado /opt/Navegador_Sankhya/
```

### 🔒 Dê Permissão de Execução

```bash
chmod +x /opt/Navegador_Sankhya/execNavegadorSankhya
chmod +x /opt/Navegador_Sankhya/resources/app/webConnection/web-connection-webclient-plugin.jar
```

### 🖱️ Crie o Atalho do Navegador Sankhya

```bash
cat <<EOF | sudo tee /usr/share/applications/navegador-sankhya.desktop
[Desktop Entry]
Name=Navegador Sankhya
Comment=Navegador Sankhya
Exec=bash -c "cd /opt/Navegador_Sankhya && ./execNavegadorSankhya"
Icon=/opt/Navegador_Sankhya/resources/icon.png
Terminal=false
Type=Application
StartupNotify=true
Categories=WebBrowser
EOF
```

---

## 🔗 2) Configuração do Serviço Web Connection

### 🛠️ Instale o java

```bash
sudo apt install default-jdk
```

### 🛠️ Crie o Serviço do WebConnection

```bash
cat <<EOF | sudo tee /etc/systemd/system/web-connection.service
[Unit]
Description=Web Connection Navegador Sankhya
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/java -jar /opt/Navegador_Sankhya/resources/app/webConnection/web-connection-webclient-plugin.jar
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
```

### 🔄 Recarrega, habilita e reinicia o serviço

```bash
sudo systemctl daemon-reload
sudo systemctl enable web-connection
sudo systemctl restart web-connection
```

### 🔍 Verifique o Status

```bash
sudo systemctl status web-connection.service
```

### 🛠️ Ajusta permissões do atalho global
```bash
sudo chmod 644 /usr/share/applications/navegador-sankhya.desktop
```

### 🛠️ Atualiza base de ícones
```bash
sudo update-desktop-database
```

### 🛠️ Garante que usuários novos recebam o atalho na área de trabalho
```bash
sudo mkdir -p /etc/skel/Desktop
sudo cp /usr/share/applications/navegador-sankhya.desktop /etc/skel/Desktop/
sudo chmod +x /etc/skel/Desktop/navegador-sankhya.desktop
```

---

🌐 3) Compartilhamento de Rede - Configuração para Todos os Usuários

Esta etapa garante que todo novo usuário:
- Monte automaticamente o compartilhamento smb://berlim/Dbclipper ao fazer login.
- Tenha um atalho na área de trabalho para abrir essa pasta.

🔄 1. Criar Autostart para Montagem do Compartilhamento

```bash
sudo mkdir -p /etc/skel/.config/autostart
```

```bash
cat <<EOF | sudo tee /etc/skel/.config/autostart/mount-dbclipper.desktop
[Desktop Entry]
Type=Application
Exec=gio mount smb://berlim/Dbclipper/PESSOAL
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Montar Publico
Comment=Montar compartilhamento de rede Dbclipper no login
EOF
```


🖥️ 2. Criar Atalho para Acesso Direto ao Compartilhamento

```bash
cat <<EOF | sudo tee /etc/skel/Desktop/dbclipper.desktop
[Desktop Entry]
Name=Publico_Miranda
Comment=Abrir compartilhamento de rede Dbclipper
Exec=gio open smb://berlim/Dbclipper/PESSOAL
Icon=folder-remote
Terminal=false
Type=Application
EOF
```

```bash
sudo chmod +x /etc/skel/Desktop/dbclipper.desktop
```

---

## 💻 4) Programas Extras

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

## 💻 5) Ingressar a máquina no AD MIRANDA.BR

✅ Iremos ingeressar a máquina no AD através do utilitário **CID** [Closed In Directory](https://cid-doc.github.io/)

- Instalação:

```bash
sudo add-apt-repository -y ppa:emoraes25/cid
```

```bash
sudo apt update && sudo apt -y install cid cid-gtk
```

✅ Após o passo anterior, um atalho com o nome **CID** aparecerá no menu de programas do AnduinOS. Basta acessar e marcar o campo "join the domain" e seguir os passos que são bastante intuitivos. Ao fim será sugerido o reinicio da máquina, aceite e, após a máquina reiniciar já estará tudo pronto. A máquina já estará no domínio **miranda.br** e pronta para fazer login com os usuários do AD.


- Documentação:

✅ Além da documentação oficial do **CID** [DOCUMENTAÇÃO OFICIAL](https://cid-doc.github.io/) existe também o canal do youtube do criador da ferramenta mostrando tudo a respeito da ferramenta. [YouTube CID](https://youtube.com/playlist?list=PLZ1ipIxs8prxiDi8YFiSRQoss_A7rnAYD&si=2dCdM6aP6NJwGFh6)

---

## ✅ 6) Finalização

- Após o reinicio da máquina, entre novamente no usuário Miranda e rode o comando a baixo para definir o nome da máquina que será propagado pela rede.

```bash
sudo hostnamectl set-hostname novo-nome-maquina
```

---

## 🎉 Tudo Pronto!

Parabéns! Seu ambiente está pronto para uso. 🚀  
Em caso de dúvidas, chame o **TI**! 👨‍💻✨
