# 🚀 Instalação e Implantação de Imagem Live Personalizada via PXE/NFS

Este guia documenta o processo completo para criar uma imagem Live personalizada do Linux Mint (ou qualquer sistema baseado em Debian/Ubuntu) usando o Systemback, e implantá-la em máquinas cliente via PXE (Preboot Execution Environment) utilizando um servidor NFS (Network File System).

O processo é otimizado para instalação rápida, remoção de ferramentas de criação de imagem e inicialização limpa.

-----

## 📋 Pré-requisitos

### Servidor (Ubuntu Server 192.168.10.225)

  * Servidor DHCP configurado.
  * Servidor TFTP (para PXE) configurado.
  * Servidor **NFS** configurado e compartilhando o diretório de dados:
      * Caminho: `/srv/nfs/backups`
      * Compartilhamento: `192.168.10.225:/srv/nfs/backups`
  * Pacote de instalação (`initrd`, `vmlinuz` e o arquivo `.squashfs`) fornecido.

### Imagem Base (Linux Mint Personalizado)

  * Sistema Linux Mint base, configurado e pronto.
  * **Systemback (Fork MaranBr)** instalado e utilizado para gerar o arquivo Live:
      * **Arquivo gerado:** `mint-miranda.squashfs` (ou similar)
      * **Localização no Servidor NFS:** `/srv/nfs/backups/mint-miranda.squashfs`

-----

## 1\. 📦 Criação da Imagem Base (`.squashfs`)

A imagem do sistema é criada usando o Systemback para capturar o estado atual da sua instalação personalizada.

1.  Instale o Systemback na sua máquina base (se ainda não estiver instalado).
2.  Gere um **"Live system create"** (Criar sistema Live).
3.  O Systemback gerará um arquivo `.sblive`.
4.  **Converta** o arquivo `.sblive` para um `.iso` e depois **extraia o arquivo `.squashfs`** de dentro do ISO.

4.1 🛠️ Extração do Arquivo `.squashfs` do ISO Live

O Systemback, após criar o "Live system", gera um arquivo `.iso` inicializável. Para a implantação via NFS, precisamos extrair o sistema de arquivos base contido nesse ISO, que está no formato **SquashFS**.

Este processo deve ser feito em uma máquina Linux que tenha o pacote `squashfs-tools` e o utilitário `mount` instalados (geralmente padrão).

4.2 Pré-requisito

Certifique-se de que as ferramentas de manipulação de imagens e SquashFS estão instaladas:

```bash
# Para sistemas baseados em Debian/Ubuntu (onde a extração será feita)
sudo apt update
sudo apt install squashfs-tools
```

4.3 Procedimento de Extração

Assumindo que o arquivo ISO Live gerado pelo Systemback se chama `miranda-live.iso`.

#### Passo 1: Crie o diretório de montagem

Crie um ponto de montagem temporário para acessar o conteúdo do ISO:

```bash
mkdir /mnt/iso_temp
```

#### Passo 2: Monte o arquivo ISO

Monte o arquivo `.iso` no ponto de montagem, utilizando o *loop device* para tratá-lo como um disco:

```bash
sudo mount -o loop miranda-live.iso /mnt/iso_temp
```

#### Passo 3: Localize o arquivo SquashFS

O Systemback ou a maioria das ISOs Live armazena o sistema de arquivos base em um local específico, geralmente chamado `filesystem.squashfs` ou similar:

```bash
ls -lh /mnt/iso_temp/casper/filesystem.squashfs
# OU (dependendo da versão)
ls -lh /mnt/iso_temp/live/filesystem.squashfs
```

> ⚠️ **Nota:** O caminho exato pode variar. Se não encontrar em `/casper` ou `/live`, explore o diretório `/mnt/iso_temp` para localizar o arquivo principal do sistema de arquivos.

#### Passo 4: Copie e Renomeie o arquivo

Copie o arquivo `.squashfs` para o seu diretório de trabalho e o renomeie conforme a convenção usada no script (`mint-miranda.squashfs`):

```bash
# Altere o caminho /casper/ conforme o encontrado no Passo 3
cp /mnt/iso_temp/casper/filesystem.squashfs ./mint-miranda.squashfs
```

#### Passo 5: Desmonte e Limpe

Desmonte a ISO e remova o diretório temporário:

```bash
sudo umount /mnt/iso_temp
rmdir /mnt/iso_temp
```

4.4 Movendo para o Servidor NFS

Com o arquivo `mint-miranda.squashfs` em mãos, mova-o para o diretório de compartilhamento no seu servidor NFS (`192.168.10.225`):

```bash
# Execute este comando na máquina onde o arquivo foi extraído
# (Assumindo que o servidor NFS esteja acessível, ou use scp)
sudo cp mint-miranda.squashfs /caminho/do/seu/ponto/de/montagem/nfs/backups/
# OU
scp mint-miranda.squashfs usuario@192.168.10.225:/srv/nfs/backups/
```

O arquivo agora está pronto para ser acessado pelo script `Instalador.sh` na máquina cliente via rede.

-----

## 2\. 📝 Script de Instalação Otimizado (Instalador.sh)

O script a seguir será executado na máquina cliente via PXE (após o boot do kernel e initrd). Ele automatiza a montagem do NFS, o particionamento, a extração e a crucial **limpeza do Systemback** para garantir um sistema limpo.

O script foi corrigido para:

1.  Remover a etapa de configuração de Hostname/Usuário.
2.  Remover o clique extra de confirmação (`zenity --info`) na listagem de discos.
3.  Incluir a remoção completa (`apt purge`) do Systemback no `chroot`.

**`Instalador.sh`**

```bash
#!/bin/bash
set -e

# ==============================================================
# 💾 INSTALADOR DE SISTEMA VIA REDE NFS (Versão Final Otimizada)
# Objetivo: Instalação robusta via PXE, com log, GUI Zenity e
#           limpeza total do Systemback pós-extração.
# ==============================================================

# --- CONFIGURAÇÕES ---
NFS_SERVER="192.168.10.225"
NFS_PATH="/srv/nfs/backups"
NFS_MOUNT="/mnt/nfs"
TARGET_MOUNT="/mnt/target"
SQUASHFS_FILE="mint-miranda.squashfs"
ROOT_LABEL="INSTALLED_ROOT" 
EFI_SIZE="512MiB"
LOG_FILE="/tmp/install.log"

# Variáveis dinâmicas
TARGET_DISK=""
ROOT_PART=""
EFI_PART=""

# --- FUNÇÕES AUXILIARES ---
msg() { zenity --info --title="Instalador de Sistema" --text="$1" --width=350; }
err() { zenity --error --title="Erro Crítico" --text="$1" --width=450; exit 1; }

# Função de limpeza para rodar em caso de erro ou término
cleanup() {
    local exit_code=$?
    echo "--- Executando limpeza de montagens temporárias... ---" | tee -a "$LOG_FILE"
    
    mountpoint -q "$TARGET_MOUNT" && umount -Rl "$TARGET_MOUNT" 2>/dev/null || true
    mountpoint -q "$NFS_MOUNT" && umount "$NFS_MOUNT" 2>/dev/null || true

    if [ "$exit_code" -ne 0 ] && [ "$exit_code" -ne 1 ]; then
        err "O script terminou inesperadamente com código de saída $exit_code.\nVerifique o log: $LOG_FILE"
    fi
}
trap cleanup EXIT

# --- PRÉ-VERIFICAÇÃO ---
check_dependencies() {
    echo "Verificando dependências..." | tee -a "$LOG_FILE"
    for cmd in mount.nfs unsquashfs parted sgdisk mkfs.ext4 mkfs.fat genfstab chroot; do
        command -v "$cmd" >/dev/null 2>&1 || err "Dependência faltando: $cmd. Instale-o."
    done
}

mount_nfs_share() {
    mkdir -p "$NFS_MOUNT"
    mountpoint -q "$NFS_MOUNT" && umount -f "$NFS_MOUNT"
    echo "Montando $NFS_SERVER:$NFS_PATH em $NFS_MOUNT..." | tee -a "$LOG_FILE"
    mount -t nfs -o vers=4,soft "$NFS_SERVER:$NFS_PATH" "$NFS_MOUNT" || err "Falha ao montar NFS.\nVerifique o servidor e o caminho: $NFS_SERVER:$NFS_PATH"
}

# --- ENTRADA DO USUÁRIO ---
select_target_disk() {
    disks=$(lsblk -ndo NAME,SIZE,TYPE | awk '$3=="disk" {print "/dev/"$1, $2}')
    [ -z "$disks" ] && err "Nenhum disco físico foi encontrado."

    selected_disk_entry=$(zenity --list \
        --title="Seleção de Disco" \
        --text="Selecione o disco destino.\n\n⚠️ ATENÇÃO: Todos os dados serão APAGADOS!" \
        --column="Caminho do Disco" --column="Tamanho" $disks \
        --width=450 --height=300)
    
    [ -z "$selected_disk_entry" ] && err "Operação cancelada pelo usuário."
    TARGET_DISK=$(echo "$selected_disk_entry")

    zenity --question --title="CONFIRMAÇÃO CRÍTICA" \
        --text="Você tem certeza que deseja APAGAR e FORMATAR o disco **$TARGET_DISK**?\n\nESTA AÇÃO É IRREVERSÍVEL!" --width=450 || err "Instalação cancelada"
}

# --- PREPARAÇÃO ---
prepare_disk() {
    echo "Preparando disco $TARGET_DISK: Particionamento GPT e UEFI..." | tee -a "$LOG_FILE"
    
    sgdisk --zap-all "$TARGET_DISK" || true
    parted -s "$TARGET_DISK" mklabel gpt
    parted -s "$TARGET_DISK" mkpart primary fat32 1MiB $EFI_SIZE
    parted -s "$TARGET_DISK" set 1 esp on
    parted -s "$TARGET_DISK" mkpart primary ext4 $EFI_SIZE 100%
    partprobe "$TARGET_DISK"
    sleep 2

    if [[ "$TARGET_DISK" =~ nvme ]]; then
        EFI_PART="${TARGET_DISK}p1"
        ROOT_PART="${TARGET_DISK}p2"
    else
        EFI_PART="${TARGET_DISK}1"
        ROOT_PART="${TARGET_DISK}2"
    fi

    echo "Formatando partições..." | tee -a "$LOG_FILE"
    mkfs.fat -F 32 -n EFI "$EFI_PART"
    mkfs.ext4 -F -L $ROOT_LABEL "$ROOT_PART"

    mkdir -p "$TARGET_MOUNT"
    mount "$ROOT_PART" "$TARGET_MOUNT"
    
    mkdir -p "$TARGET_MOUNT/boot/efi"
    mount "$EFI_PART" "$TARGET_MOUNT/boot/efi"
    echo "Partições montadas com sucesso." | tee -a "$LOG_FILE"
}

# --- EXTRAÇÃO ---
extract_system() {
    msg "Extraindo o sistema (isso pode levar alguns minutos)..."
    [ ! -f "$NFS_MOUNT/$SQUASHFS_FILE" ] && err "$SQUASHFS_FILE não encontrado em $NFS_MOUNT!"

    echo "Iniciando extração do SquashFS..." | tee -a "$LOG_FILE"
    unsquashfs -f -d "$TARGET_MOUNT" "$NFS_MOUNT/$SQUASHFS_FILE" >> "$LOG_FILE" 2>&1 &
    local extract_pid=$!
    
    ( 
        while kill -0 "$extract_pid" 2>/dev/null; do 
            echo "# Extraindo $SQUASHFS_FILE. Em andamento..."
            sleep 1
        done
        wait "$extract_pid"
    ) | zenity --progress \
        --title="Extração em Andamento" \
        --text="Instalando sistema base..." \
        --pulsate --auto-close --no-cancel --width=400
        
    if [ $? -ne 0 ]; then
        err "Falha na extração do sistema. Verifique o log: $LOG_FILE"
    fi
}

# --- CONFIGURAÇÃO PÓS-EXTRAÇÃO E LIMPEZA (CORRIGIDA) ---
configure_system() {
    echo "Iniciando configuração de fstab, GRUB e limpeza completa do Systemback..." | tee -a "$LOG_FILE"
    
    # 1. fstab e Montagens Chroot
    genfstab -U "$TARGET_MOUNT" > "$TARGET_MOUNT/etc/fstab"
    for dir in dev sys proc; do
        mount --bind /$dir "$TARGET_MOUNT/$dir"
    done

    # 2. Criação do Script de GRUB e Limpeza Interna
    cat <<EOF > "$TARGET_MOUNT/tmp/chroot_grub.sh"
#!/bin/bash
set -e
echo "Configurando GRUB e limpando Systemback profundamente..."

# A. Remoção Completa do Systemback (APT PURGE)
if command -v systemback >/dev/null 2>&1; then
    apt update >> /dev/null 2>&1
    apt purge -y systemback >> /dev/null 2>&1
    apt autoremove -y >> /dev/null 2>&1
    echo "Systemback removido via APT."
fi

# B. Limpeza Profunda de Resíduos (CRUCIAL PARA O ERRO NO LOGIN)
echo "Removendo serviços, temporários, logs e autostart residuais do Systemback..."

# B.1. Remoção dos Arquivos de Autostart de Sessão
# Estes arquivos causam a tentativa de iniciar o agendador no login gráfico (sbschedule.desktop)
rm -f /etc/xdg/autostart/sbschedule.desktop
rm -f /etc/xdg/autostart/sbschedule-kde.desktop
rm -f /etc/xdg/autostart/systemback.desktop

# B.2. Limpeza de Daemons e Configurações de Serviço
rm -f /etc/systemd/system/systemback-scheduler.service
rm -f /etc/init.d/systemback-schedule
rm -rf /var/log/systemback
rm -rf /var/cache/systemback
rm -rf /root/systemback*

# B.3. Recarrega o systemd para garantir que o serviço seja desabilitado
systemctl daemon-reload

# C. Instalação e atualização do GRUB
if grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=LinuxMintUEFI --recheck; then
    echo "GRUB UEFI instalado com sucesso."
elif grub-install --target=i386-pc $TARGET_DISK --recheck; then
    echo "GRUB BIOS/Legacy instalado com sucesso."
else
    echo "ERRO: Falha ao instalar GRUB em ambos os modos."
    exit 1
fi

update-grub

echo "Configuração do GRUB e limpeza concluídas."
EOF

    # 3. Execução do Chroot
    chmod +x "$TARGET_MOUNT/tmp/chroot_grub.sh"
    chroot "$TARGET_MOUNT" /bin/bash -c "TARGET_DISK='$TARGET_DISK' /tmp/chroot_grub.sh" >> "$LOG_FILE" 2>&1 || err "Falha na configuração interna. Verifique o log."
    
    # 4. Limpeza
    rm "$TARGET_MOUNT/tmp/chroot_grub.sh"
}

final_message() {
    trap - EXIT
    msg "✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!\n\nO sistema foi instalado em $TARGET_DISK. Você pode reiniciar o computador agora."
    exit 0
}

# --- EXECUÇÃO PRINCIPAL ---
main() {
    [ "$EUID" -ne 0 ] && err "Este script deve ser rodado como root (sudo)."
    echo "Iniciando instalador de sistema via NFS. Log em $LOG_FILE" | tee -a "$LOG_FILE"

    check_dependencies
    mount_nfs_share
    select_target_disk
    prepare_disk
    extract_system
    configure_system
    final_message
}

main
```

-----

-----

## 3\. 📂 Posicionamento do Script de Instalação no ISO Live

O arquivo `Instalador.sh` deve ser incluído na sua imagem base do Linux Mint em um local que **não será excluído** pelo Systemback e que seja facilmente acessível na sessão Live.

### 3.1. Localização Segura do Arquivo

O Systemback, por padrão, exclui ou trata de forma especial os diretórios do usuário (como `/home/usuario` e `~/Desktop`). Para garantir que o script esteja acessível e seja preservado:

| Arquivo | Localização Segura Sugerida |
| :--- | :--- |
| `Instalador.sh` | **`/opt/Instalador.sh`** |
| `atalho.desktop` | **`/etc/skel/Desktop/Instalador.desktop`** |

### 3.2. Inclusão do Script no Sistema Base

Antes de gerar a imagem `.squashfs` com o Systemback, execute os seguintes passos na sua máquina base personalizada:

#### Passo 1: Copie o Script para `/opt/`

Coloque o script de instalação no diretório `/opt/` e torne-o executável.

```bash
# Na sua máquina base, antes de rodar o Systemback:
sudo cp /caminho/do/Instalador.sh /opt/
sudo chmod +x /opt/Instalador.sh
```

#### Passo 2: Crie o Atalho de Área de Trabalho (Desktop Shortcut)

Para que o atalho apareça na Área de Trabalho de **qualquer novo usuário** criado na sessão Live (ou após a instalação, se você mantiver o usuário *Live*), use o diretório `/etc/skel/`.

Crie o arquivo `Instalador.desktop` no diretório de *template* do usuário:

```bash
# Na sua máquina base, antes de rodar o Systemback:
sudo mkdir -p /etc/skel/Desktop/

# Crie o arquivo .desktop
sudo tee /etc/skel/Desktop/Instalador.desktop <<EOF
[Desktop Entry]
Name=Instalador NFS
Comment=Executa o script de instalação do sistema via NFS.
Exec=sudo zenity --password | sudo -S /opt/Instalador.sh
Icon=system-run
Terminal=false
Type=Application
Categories=System;
StartupNotify=true
EOF

# Garanta que seja executável (necessário para que o desktop o trate como launcher)
sudo chmod +x /etc/skel/Desktop/Instalador.desktop
```

> **Explicação da linha `Exec`:** `Exec=sudo zenity --password | sudo -S /opt/Instalador.sh`
>
>   * Isto é essencial para que o script rode com privilégios de `root` ao ser clicado na sessão Live.
>   * `zenity --password` abre uma caixa de diálogo para pedir a senha.
>   * O `| sudo -S` permite que a senha fornecida pelo Zenity seja passada para o `sudo`, executando o `/opt/Instalador.sh` como `root`.

#### Passo 3: Geração da Imagem Live

Agora, você pode rodar o **Systemback** e criar o **Live system**.

  * Certifique-se de que a opção **"Include user data files"** (Incluir arquivos de dados do usuário) esteja **DESMARCADA** no Systemback, a menos que você queira incluir os arquivos do usuário que está gerando a ISO.
      * *Se esta opção estiver desmarcada,* o Systemback usa `/etc/skel` como base para os dados do usuário Live, garantindo que o atalho que você criou será incluído.

Com isso, o script estará seguro em `/opt/` e o atalho estará visível na área de trabalho da sessão Live para iniciar a instalação.

-----

## 4\. 🧰 Dependências no Ambiente de Instalação

O ambiente Live que executa o `Instalador.sh` deve ter os seguintes pacotes instalados (o `check_dependencies` verifica isso):

  * `mount.nfs` (geralmente incluído no `nfs-common`)
  * `unsquashfs` (geralmente incluído no `squashfs-tools`)
  * `parted`, `sgdisk`
  * `mkfs.ext4`, `mkfs.fat`
  * **`genfstab`** (vem no pacote `arch-install-scripts`)
  * `zenity` (para a interface gráfica)
