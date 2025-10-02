# 📘 Guia Completo: Implantação de Imagem Linux Mint via Rede com PXE, Rescuezilla e Samba

Este tutorial detalha como configurar um **servidor centralizado** para implantar uma imagem de backup personalizada do **Linux Mint** em outras máquinas da rede.  

O servidor hospedará o ambiente de boot (**PXE**) e a imagem de backup (**Samba**).

---

## 🏗️ Arquitetura da Solução

- **Servidor de Implantação (VM com Ubuntu Server):**
  - **IP Estático:** `192.168.1.100` (exemplo, use o seu IP real).
  - **Serviço TFTP:** entrega os arquivos de boot iniciais.
  - **Serviço NFS:** entrega o sistema de arquivos do Rescuezilla.
  - **Serviço Samba (CIFS):** compartilha a pasta com a imagem de backup do Linux Mint.

- **Servidor DHCP (Windows Server):**
  - Atribui IPs e informa aos clientes onde encontrar o servidor de boot.

- **Máquinas Clientes:**
  - Computadores que inicializarão pela rede para serem restaurados.

---

## 🚀 Passo 1: Preparar o Servidor de Implantação (Ubuntu Server 22.04 LTS)

Esta VM será o coração da operação de implantação.

### 1. Instalar o Ubuntu Server 22.04 LTS
- Configure um endereço **IP estático** durante a instalação (ex: `192.168.1.100`).

### 2. Instalar pacotes necessários
Conecte-se ao servidor via SSH e execute:

```bash
sudo apt update
sudo apt install -y tftpd-hpa nfs-kernel-server pxelinux syslinux-common samba
```

### 3. Criar estrutura de diretórios
```bash
# Diretório raiz para o TFTP (boot)
sudo mkdir -p /srv/tftp/pxelinux.cfg

# Diretório para o sistema de arquivos do Rescuezilla (via NFS)
sudo mkdir -p /srv/nfs/rescuezilla

# Diretório para as imagens de backup (via Samba)
sudo mkdir -p /srv/backups
```

### 4. Copiar arquivos de boot do PXELINUX
```bash
sudo cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/libcom32.c32 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/libutil.c32 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/vesamenu.c32 /srv/tftp/
```

---

## 📦 Passo 2: Preparar Rescuezilla e a Imagem de Backup

### 1. Upload dos arquivos
- Transfira o **ISO do Rescuezilla** (ex: `rescuezilla-2.5-64bit.iso`) para o diretório home do servidor.
- Transfira a **pasta de backup** criada pelo Rescuezilla para o home do servidor.

### 2. Mover pasta de backup para o Samba
```bash
# Substitua pelo nome real da pasta
sudo mv ~/rescuezilla-bkp-YYYYMMDD-HHMM_hostname /srv/backups/
```

### 3. Montar ISO e copiar arquivos
```bash
# Monte o ISO
sudo mount -o loop ~/rescuezilla-2.5-64bit.iso /mnt

# Copie o sistema do Rescuezilla para NFS
sudo cp -r /mnt/* /srv/nfs/rescuezilla/

# Copie kernel e initrd para o TFTP
sudo cp /srv/nfs/rescuezilla/casper/vmlinuz /srv/tftp/
sudo cp /srv/nfs/rescuezilla/casper/initrd.lz /srv/tftp/

# Desmonte
sudo umount /mnt
```

---

## ⚙️ Passo 3: Configurar os Serviços de Rede

### 1. Configurar TFTP
```bash
sudo nano /etc/default/tftpd-hpa
```

Conteúdo:
```text
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
```

### 2. Configurar NFS
```bash
sudo nano /etc/exports
```

Adicione:
```text
/srv/nfs/rescuezilla    192.168.1.0/24(ro,sync,no_subtree_check)
```

### 3. Configurar Samba
```bash
sudo nano /etc/samba/smb.conf
```

Adicione ao final:
```ini
[backups]
   comment = Imagens de Backup para Implantação
   path = /srv/backups
   read only = yes
   browsable = yes
   guest ok = yes
```

### 4. Reiniciar e habilitar serviços
```bash
sudo systemctl restart tftpd-hpa nfs-kernel-server smbd nmbd
sudo systemctl enable tftpd-hpa nfs-kernel-server smbd nmbd
```

---

## 🖥️ Passo 4: Criar o Menu de Boot PXE

```bash
sudo nano /srv/tftp/pxelinux.cfg/default
```

Conteúdo:
```text
DEFAULT vesamenu.c32
PROMPT 0
TIMEOUT 300 # Tempo em décimos de segundo (30s)
MENU TITLE Menu de Implantação da Empresa

LABEL rescuezilla
  MENU LABEL Iniciar Ambiente de Restauração (Rescuezilla)
  KERNEL vmlinuz
  APPEND initrd=initrd.lz boot=casper netboot=nfs nfsroot=192.168.1.100:/srv/nfs/rescuezilla ip=dhcp --
```

---

## 📡 Passo 5: Configurar o Servidor DHCP (Windows Server)

1. Abra o console do **DHCP** no Windows Server.  
2. Vá em **IPv4 > Opções de Escopo > Configurar Opções**.  
3. Configure:  
   - **066 - Nome do Host do Servidor de Inicialização:** `192.168.1.100`  
   - **067 - Nome do Arquivo de Inicialização:** `pxelinux.0`  

---

## 💻 Passo 6: Processo de Implantação na Máquina Cliente

1. **Configurar BIOS/UEFI**
   - Habilite boot pela rede (PXE Boot).
   - Coloque a placa de rede como **primeiro dispositivo**.

2. **Boot pela rede**
   - Cliente recebe IP via DHCP.
   - Menu PXE aparece → selecione *Iniciar Ambiente de Restauração*.
   - Rescuezilla é carregado.

3. **Restauração via Samba**
   - No Rescuezilla, selecione **Restaurar (Restore)**.  
   - Escolha **Conectar a um Servidor de Rede (Samba/CIFS)**.  
   - Preencha:
     - Servidor: `192.168.1.100`
     - Compartilhamento: `backups`
     - Usuário/Senha: (em branco)

   - Conecte, escolha a imagem e restaure.

---

## ✅ Conclusão

Após a restauração, **remova o boot PXE da BIOS** para inicializar pelo disco rígido.  
Seu sistema **Linux Mint personalizado** estará pronto para uso 🚀.
