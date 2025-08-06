
<h1 align="center">🚀 Guia Rápido de Instalação e Configuração - Anduin OS Miranda</h1>

Este guia vai te ajudar a instalar e configurar o **Anduin OS**, ou qualquer outra distribuição Linux baseada em **Debian**, com o **Navegador Sankhya** e alguns outros softwares essenciais.  
➡️ **Siga os passos na ordem correta para garantir o sucesso da configuração!** 😉

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/3/35/Tux.svg" alt="Linux Logo" width="200" style="margin-right: 140px;"/>
  <img src="https://lh3.googleusercontent.com/d/1gVGI0GgiIywENstJnNwp_kqD1DG3kNfv" alt="Logo Miranda" width="240"/>
</p>

---

## 🗂️ 1) Instalação do Navegador Sankhya

### 📁 Crie a pasta "Navegador_Sankhya" em `/opt`

```bash
sudo mkdir /opt/Navegador_Sankhya
```

### 🌐 Baixe o Navegador Sankhya

Acesse o site oficial da Sankhya e faça o download do navegador:  
🔗 [Página de Download do Navegador Sankhya](https://downloads.sankhya.com.br/)

### 📦 Extraia e copie os arquivos

Após extrair o conteúdo, copie **apenas os arquivos internos** (e não a pasta principal extraída) para a pasta de destino:

```bash
sudo cp -r diretorio_do_arquivo_baixado/* /opt/Navegador_Sankhya/
```

### 🔐 Dê permissões de execução

```bash
chmod +x /opt/Navegador_Sankhya/execNavegadorSankhya
chmod +x /opt/Navegador_Sankhya/resources/app/webConnection/web-connection-webclient-plugin.jar
```

### 🖱️ Crie um atalho para o Navegador Sankhya

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

### ☕ Instale o Java

```bash
sudo apt install default-jdk
```

### 🧩 Crie o serviço systemd para o WebConnection

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

### 🔄 Recarregue, habilite e inicie o serviço

```bash
sudo systemctl daemon-reload
sudo systemctl enable web-connection
sudo systemctl restart web-connection
```

### 🔍 Verifique o status do serviço

```bash
sudo systemctl status web-connection.service
```

### ⚙️ Ajuste permissões e atalho global

```bash
sudo chmod 644 /usr/share/applications/navegador-sankhya.desktop
sudo update-desktop-database
```

### 👥 Garante que novos usuários recebam o atalho

```bash
sudo mkdir -p /etc/skel/Desktop
sudo cp /usr/share/applications/navegador-sankhya.desktop /etc/skel/Desktop/
sudo chmod +x /etc/skel/Desktop/navegador-sankhya.desktop
```

---

## 🌐 3) Compartilhamento de Rede - Padrão para Usuários

### 📝 Edite o arquivo `shares.xml` na pasta `\berlim\NETLOGON\cid`

Adicione o seguinte trecho, caso não exista:

```xml
<pam_mount>
    <volume
        user="*"
        fstype="cifs"
        server="berlim"
        path="Dbclipper\PESSOAL"
        mountpoint="~/Rede/Dbclipper"
        options="rw,iocharset=utf8,sec=ntlmssp,domain=MIRANDA.BR" />
</pam_mount>
```

🔒 Isso garantirá que a pasta pessoal seja montada automaticamente para todos os usuários do AD.

### 🖱️ Crie o atalho para a pasta compartilhada

```bash
sudo mkdir -p /etc/Dbclipper
sudo nano /etc/Dbclipper/Dbclipper.template.desktop
```

Insira o seguinte conteúdo:

```desktop
[Desktop Entry]
Name=Publico_Miranda
Comment=Acesso à pasta Dbclipper
Exec=xdg-open /home/USUARIO/Rede/Dbclipper
Icon=folder
Terminal=false
Type=Application
Categories=Network;
```

Dê permissão de execução:

```bash
sudo chmod +x /etc/Dbclipper/Dbclipper.template.desktop
```

### ⚙️ Script de login para criar atalho personalizado

```bash
sudo nano /etc/profile.d/copy_desktop_shortcut.sh
```

Conteúdo do script:

```bash
#!/bin/bash

USER_HOME="/home/$USER"
DESKTOP="$USER_HOME/Desktop"
TARGET="$DESKTOP/Dbclipper.desktop"
TEMPLATE="/etc/Dbclipper/Dbclipper.template.desktop"

rm -f "$DESKTOP/Dbclipper.template.desktop"

if [ ! -f "$TARGET" ]; then
    cp "$TEMPLATE" "$TARGET"
    sed -i "s|/home/USUARIO|/home/$USER|g" "$TARGET"
    chmod +x "$TARGET"
fi
```

Permissão de execução:

```bash
sudo chmod +x /etc/profile.d/copy_desktop_shortcut.sh
```

---

## 📞 4) Criar Atalho para Ramais Miranda

```bash
cat <<EOF | sudo tee /etc/skel/Desktop/ramais_miranda.desktop
[Desktop Entry]
Name=Ramais Miranda
Comment=Lista de Ramais da Empresa
Exec=xdg-open http://192.168.54.2/ramais/
Icon=contacts-symbolic
Terminal=false
Type=Application
Categories=Network;
EOF
```

---

## 🧰 5) Programas Extras

✅ **OnlyOffice:** Instale pela loja de aplicativos do sistema.  
✅ **Configurações da Impressora:** Também disponível pela loja.

🧩 **TeamViewer Host:**  
🔗 [Download TeamViewer Host](https://download.teamviewer.com/download/linux/teamviewer-host_amd64.deb)

📦 Para instalar: basta dar dois cliques no arquivo `.deb` baixado.

🖨️ **Drivers HP (HPLIP):**

```bash
sudo apt install hplip
```

---

## 🔄 6) Alterar de Wayland para X11

Para garantir compatibilidade com mais programas:

```bash
sudo nano /etc/gdm3/custom.conf
```

Altere a linha:

```bash
#WaylandEnable=false
```

Para:

```bash
WaylandEnable=false
```

Salve, feche o arquivo e reinicie:

```bash
sudo reboot
```

---

## 🏢 7) Ingressar no Domínio AD `MIRANDA.BR`

Use o utilitário **CID (Closed In Directory)**:  
📘 [Documentação oficial](https://cid-doc.github.io/)  
📺 [Canal do YouTube com tutoriais](https://youtube.com/playlist?list=PLZ1ipIxs8prxiDi8YFiSRQoss_A7rnAYD)

### 🧩 Instalação do CID:

```bash
sudo add-apt-repository -y ppa:emoraes25/cid
sudo apt update && sudo apt -y install cid cid-gtk
```

✅ Após a instalação, abra o programa **CID**, marque a opção “Join the domain” e siga os passos. Após concluir, reinicie a máquina.

---

## ✅ 8) Finalização

🔧 Após o login de cada usuário, recomenda-se:

- ⚡ Ajustar as configurações de energia (evitar suspensão automática).
- 💼 Configurar o TeamViewer para evitar encerramento pelo usuário.
- 🌐 Cadastrar a base de produção no Sankhya-Om.
- 🌦️ (Opcional) Ajustar localização no app de clima.

---

## 🎉 Tudo Pronto!

Parabéns! Seu ambiente Linux está completamente configurado e pronto para uso. 🚀  
Em caso de dúvidas ou problemas, entre em contato com o **time de TI**! 👨‍💻💚
