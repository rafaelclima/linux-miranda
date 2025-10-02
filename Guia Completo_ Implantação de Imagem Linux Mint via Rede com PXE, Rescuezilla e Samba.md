# Guia Completo: Implantação de Imagem Linux Mint via Rede com PXE, Rescuezilla e Samba

Este tutorial detalha como configurar um servidor centralizado para implantar uma imagem de backup personalizada do Linux Mint em outras máquinas da rede. O servidor hospedará o ambiente de boot (PXE) e a imagem de backup (Samba).

**Arquitetura da Solução:**

*   **Servidor de Implantação (Sua VM com Ubuntu Server):**
    *   **IP Estático:** `192.168.1.100` (exemplo, use o seu IP real).
    *   **Serviço TFTP:** Entrega os arquivos de boot iniciais.
    *   **Serviço NFS:** Entrega o sistema de arquivos do Rescuezilla.
    *   **Serviço Samba (CIFS):** Compartilha a pasta com a imagem de backup do Linux Mint.
*   **Servidor DHCP (Seu Windows Server):** Atribui IPs e informa aos clientes onde encontrar o servidor de boot.
*   **Máquinas Clientes:** Computadores que inicializarão pela rede para serem restaurados.

---

### Passo 1: Preparar o Servidor de Implantação (VM com Ubuntu Server 22.04 LTS)

Esta VM será o coração da sua operação de implantação.

1.  **Instale o Ubuntu Server 22.04 LTS:**
    *   Durante a instalação, configure um **endereço IP estático** (ex: `192.168.1.100`). Isso é crucial.

2.  **Instale Todos os Pacotes Necessários:**
    Conecte-se ao servidor via SSH e instale os serviços TFTP, NFS, PXELINUX e Samba de uma só vez.
    ```bash
sudo apt update
sudo apt install -y tftpd-hpa nfs-kernel-server pxelinux syslinux-common samba
    ```

3.  **Crie a Estrutura de Diretórios:**
    Vamos organizar todos os arquivos necessários em uma estrutura lógica no diretório `/srv`.
    ```bash
# Diretório raiz para o TFTP (boot)
sudo mkdir -p /srv/tftp/pxelinux.cfg

# Diretório para o sistema de arquivos do Rescuezilla (via NFS)
sudo mkdir -p /srv/nfs/rescuezilla

# Diretório para as imagens de backup (via Samba)
sudo mkdir -p /srv/backups
    ```

4.  **Copie os Arquivos de Boot do PXELINUX:**
    Esses arquivos são os "bootloaders" que os clientes usarão.
    ```bash
sudo cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/libcom32.c32 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/libutil.c32 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/vesamenu.c32 /srv/tftp/
    ```

### Passo 2: Preparar os Arquivos do Rescuezilla e a Imagem de Backup

1.  **Faça o Upload dos Arquivos:**
    *   Transfira o arquivo **ISO do Rescuezilla** (ex: `rescuezilla-2.5-64bit.iso`) para o diretório home do seu servidor.
    *   Transfira a **pasta de backup** criada pelo Rescuezilla (ex: `rescuezilla-bkp-YYYYMMDD-HHMM_hostname`) para o diretório home do seu servidor.

2.  **Posicione a Imagem de Backup:**
    Mova a pasta de backup para o diretório que será compartilhado via Samba.
    ```bash
# Substitua pelo nome real da sua pasta de backup
sudo mv ~/rescuezilla-bkp-YYYYMMDD-HHMM_hostname /srv/backups/
    ```

3.  **Extraia e Posicione os Arquivos do Rescuezilla:**
    *   Monte o ISO para acessar seu conteúdo.
        ```bash
# Substitua pelo nome do seu arquivo ISO
sudo mount -o loop ~/rescuezilla-2.5-64bit.iso /mnt
        ```
    *   Copie o sistema de arquivos do Rescuezilla para o diretório NFS.
        ```bash
sudo cp -r /mnt/* /srv/nfs/rescuezilla/
        ```
    *   Copie o kernel e o initrd (arquivos de inicialização) para o diretório TFTP.
        ```bash
sudo cp /srv/nfs/rescuezilla/casper/vmlinuz /srv/tftp/
sudo cp /srv/nfs/rescuezilla/casper/initrd.lz /srv/tftp/
        ```
    *   Limpe o ponto de montagem.
        ```bash
sudo umount /mnt
        ```

### Passo 3: Configurar os Serviços de Rede (TFTP, NFS, Samba)

1.  **Configurar o Servidor TFTP:**
    Edite o arquivo de configuração para apontar para o diretório correto.
    ```bash
sudo nano /etc/default/tftpd-hpa
    ```
    Garanta que o conteúdo seja este:
    ```
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
    ```

2.  **Configurar o Servidor NFS:**
    Exporte o diretório do sistema Rescuezilla para a sua rede.
    ```bash
sudo nano /etc/exports
    ```
    Adicione a seguinte linha, ajustando a faixa de IP se necessário:
    ```
/srv/nfs/rescuezilla    192.168.1.0/24(ro,sync,no_subtree_check)
    ```

3.  **Configurar o Servidor Samba:**
    Crie o compartilhamento de rede para a pasta de backups.
    ```bash
sudo nano /etc/samba/smb.conf
    ```
    Adicione este bloco no final do arquivo para criar um compartilhamento de convidado (sem senha) e somente leitura:
    ```ini
[backups]
   comment = Imagens de Backup para Implantação
   path = /srv/backups
   read only = yes
   browsable = yes
   guest ok = yes
    ```

4.  **Reinicie e Habilite Todos os Serviços:**
    Aplique todas as configurações reiniciando e habilitando os serviços para que iniciem com o boot.
    ```bash
sudo systemctl restart tftpd-hpa nfs-kernel-server smbd nmbd
sudo systemctl enable tftpd-hpa nfs-kernel-server smbd nmbd
    ```

### Passo 4: Criar o Menu de Boot PXE

Este arquivo define o menu que o usuário verá ao iniciar pela rede.

1.  **Crie o arquivo de configuração `default`:**
    ```bash
sudo nano /srv/tftp/pxelinux.cfg/default
    ```
2.  **Cole o seguinte conteúdo:**
    **Lembre-se de substituir `192.168.1.100` pelo IP real do seu servidor.**
    ```
DEFAULT vesamenu.c32
PROMPT 0
TIMEOUT 300 # Tempo em décimos de segundo (30s)
MENU TITLE Menu de Implantação da Empresa

LABEL rescuezilla
  MENU LABEL Iniciar Ambiente de Restauração (Rescuezilla)
  KERNEL vmlinuz
  APPEND initrd=initrd.lz boot=casper netboot=nfs nfsroot=192.168.1.100:/srv/nfs/rescuezilla ip=dhcp --
    ```

### Passo 5: Configurar o Servidor DHCP (Windows Server)

Instrua seu servidor DHCP a direcionar os clientes para o servidor PXE.

1.  Abra o console de gerenciamento do **DHCP** no Windows Server.
2.  Vá para `IPv4`, clique com o botão direito em **Opções de Escopo** e selecione **Configurar Opções...**.
3.  Marque a **Opção 066 - Nome do Host do Servidor de Inicialização**:
    *   **Valor da cadeia de caracteres:** Insira o IP do seu servidor PXE (ex: `192.168.1.100`).
4.  Marque a **Opção 067 - Nome do Arquivo de Inicialização**:
    *   **Valor da cadeia de caracteres:** Insira `pxelinux.0`.
5.  Clique em **Aplicar** e **OK**.

### Passo 6: Processo de Implantação na Máquina Cliente

1.  **Configure a BIOS/UEFI do Cliente:**
    *   Ligue a máquina cliente e entre na BIOS/UEFI (pressionando F2, F12, DEL, etc.).
    *   Habilite o boot pela rede (`PXE Boot`, `Boot from LAN`).
    *   Defina a placa de rede como o primeiro dispositivo na ordem de boot.
    *   Salve e reinicie.

2.  **Boot pela Rede:**
    *   A máquina obterá um IP do DHCP e será direcionada para o servidor PXE.
    *   O menu de boot que você criou aparecerá. Selecione "Iniciar Ambiente de Restauração".
    *   O Rescuezilla será carregado na memória.

3.  **Restaure a Imagem:**
    *   Na interface do Rescuezilla, selecione **Restaurar (Restore)**.
    *   Escolha a opção **"Conectar a um Servidor de Rede" (Samba/CIFS)**.
    *   Preencha os dados:
        *   **Servidor:** `192.168.1.100`
        *   **Compartilhamento:** `backups`
        *   Deixe **usuário e senha em branco**.
    *   Clique em conectar. Sua pasta de backup aparecerá.
    *   Selecione a imagem, o disco de destino e inicie a restauração.

Após a conclusão, remova a prioridade de boot pela rede na BIOS do cliente para que ele inicie a partir do disco rígido recém-restaurado. Seu sistema Linux Mint personalizado estará pronto para uso.

