
<h1 align="center">🚀 Guia de Instalação e Configuração - Anduin OS Miranda</h1>

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
sudo cp -r /home/miranda/Download/nome_da_pasta_extraida/* /opt/Navegador_Sankhya/
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

### 📝 Edite o arquivo `shares.xml` na pasta `\\berlim\NETLOGON\cid`

Adicione o seguinte trecho, caso não exista:

```xml
<pam_mount>
	<!-- Application control tags (RECOMMENDED DO NOT MAKE CHANGES) -->
	<debug enable="0" />
	<mkmountpoint enable="1" remove="true" />
	<logout wait="0" hup="yes" term="yes" kill="yes" />

	<!-- DECLARE HERE YOUR VOLUMES ("<volume... />" tags)! -->
	
  <volume sgrp="gloja 5" fstype="cifs" server="berlim" path="Dbclipper\PESSOAL" mountpoint="~/Publico_LJ05" />
	<volume sgrp="gloja 1" fstype="cifs" server="berlim" path="01" mountpoint="~/Publico_LJ01" />
	<volume sgrp="gloja 2" fstype="cifs" server="berlim" path="02" mountpoint="~/Publico_LJ02" />
	<volume sgrp="gloja 7" fstype="cifs" server="berlim" path="07" mountpoint="~/Publico_LJ07" />
	<volume sgrp="gloja 8" fstype="cifs" server="berlim" path="08" mountpoint="~/Publico_LJ08" />
	<volume sgrp="gloja 11" fstype="cifs" server="berlim" path="11" mountpoint="~/Publico_LJ011" />

</pam_mount>
```

🔒 Isso garantirá que a pasta pessoal seja montada automaticamente para todos os usuários do AD.

### 🖱️ Crie o atalho para a pasta compartilhada

⚙️ Crie o atalho e o script de login para criar atalho personalizado

```bash
sudo nano /etc/profile.d/create_network_shortcuts.sh
```

Conteúdo do script:

```bash
#!/bin/bash
USER_HOME="/home/$USER"
DESKTOP="$USER_HOME/Desktop"
SHARES_FILE="/etc/security/pam_mount.conf.xml"

mkdir -p "$DESKTOP"

# Limpa atalhos antigos criados por este script
find "$DESKTOP" -maxdepth 1 -type f -name "NetShare_*.desktop" -delete

# Percorre volumes configurados
grep "<volume" "$SHARES_FILE" | while read -r line; do
    # Extrai o mountpoint
    MOUNTPOINT=$(echo "$line" | sed -n 's/.*mountpoint="\([^"]*\)".*/\1/p')

    # Substitui variáveis tipo ~ e %h
    MOUNTPOINT=${MOUNTPOINT//\~/$USER_HOME}
    MOUNTPOINT=${MOUNTPOINT//%h/$USER_HOME}

    if [ -d "$MOUNTPOINT" ]; then
        # Nome amigável pro atalho
        NAME=$(basename "$MOUNTPOINT")

        SHORTCUT="$DESKTOP/NetShare_${NAME}.desktop"
        cat <<EOF > "$SHORTCUT"
[Desktop Entry]
Name=$NAME
Comment=Atalho para $NAME
Exec=xdg-open "$MOUNTPOINT"
Icon=folder
Terminal=false
Type=Application
Categories=Network;
EOF
        chmod +x "$SHORTCUT"
    fi
done

```

Permissão de execução:

```bash
sudo chmod +x /etc/profile.d/create_network_shortcuts.sh
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
