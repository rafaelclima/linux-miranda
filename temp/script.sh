#!/bin/bash
set -e

# ==============================================================
# 💾 INSTALADOR DE SISTEMA VIA REDE NFS (Versão Final - UEFI Fix)
# Objetivo: Instalação robusta via PXE, com log, GUI Zenity,
#           limpeza do Systemback e correção de boot para VirtualBox/Hardware.
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
    
    # Tenta desmontar recursivamente o alvo
    if mountpoint -q "$TARGET_MOUNT"; then
        umount -Rl "$TARGET_MOUNT" 2>/dev/null || true
    fi
    
    # Desmonta o NFS
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
    
    # 1. fstab
    genfstab -U "$TARGET_MOUNT" > "$TARGET_MOUNT/etc/fstab"

    # 2. Montagens Chroot (ESSENCIAL PARA UEFI)
    for dir in dev proc sys; do
        mount --bind /$dir "$TARGET_MOUNT/$dir"
    done
    
    # 2.1 Montagem específica das variáveis EFI (Correção do erro da imagem)
    if [ -d /sys/firmware/efi/efivars ]; then
        echo "Montando efivars para acesso UEFI..." | tee -a "$LOG_FILE"
        mount --bind /sys/firmware/efi/efivars "$TARGET_MOUNT/sys/firmware/efi/efivars"
    fi

    # 3. Criação do Script de GRUB e Limpeza Interna
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

# B. Limpeza Profunda de Resíduos
echo "Removendo serviços, temporários, logs e autostart residuais do Systemback..."
rm -f /etc/xdg/autostart/sbschedule.desktop
rm -f /etc/xdg/autostart/sbschedule-kde.desktop
rm -f /etc/xdg/autostart/systemback.desktop
rm -f /etc/systemd/system/systemback-scheduler.service
rm -f /etc/init.d/systemback-schedule
rm -rf /var/log/systemback
rm -rf /var/cache/systemback
rm -rf /root/systemback*

# Recarrega o systemd para garantir que o serviço seja desabilitado
systemctl daemon-reload

# C. Instalação do GRUB (BLINDAGEM CONTRA ERROS UEFI)
echo "Instalando GRUB..."

if [ -d /sys/firmware/efi ]; then
    # Estratégia Dupla para UEFI:
    # 1. Tenta instalar no caminho removível/padrão (Resolve problemas de VM/BIOS restrita)
    echo "Tentando instalação EFI Removable (Fallback)..."
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=LinuxMint --recheck --removable --no-nvram || true
    
    # 2. Tenta instalar registrando na NVRAM (Padrão)
    echo "Tentando instalação EFI Padrão (NVRAM)..."
    if grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=LinuxMint --recheck; then
        echo "GRUB UEFI instalado e registrado na NVRAM com sucesso."
    else
        echo "AVISO: Falha ao registrar na NVRAM (comum em VMs). O boot deve funcionar via fallback removível instalado acima."
    fi
else
    # Modo Legacy/BIOS
    grub-install --target=i386-pc $TARGET_DISK --recheck
    echo "GRUB BIOS/Legacy instalado com sucesso."
fi

update-grub

echo "Configuração do GRUB e limpeza concluídas."
EOF

    # 4. Execução do Chroot
    chmod +x "$TARGET_MOUNT/tmp/chroot_grub.sh"
    chroot "$TARGET_MOUNT" /bin/bash -c "TARGET_DISK='$TARGET_DISK' /tmp/chroot_grub.sh" >> "$LOG_FILE" 2>&1 || err "Falha na configuração interna. Verifique o log."
    
    # 5. Limpeza
    rm "$TARGET_MOUNT/tmp/chroot_grub.sh"
}

final_message() {
    trap - EXIT
    msg "✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!\n\nO sistema foi instalado em $TARGET_DISK.\nAs correções de boot para VirtualBox/UEFI foram aplicadas.\n\nVocê pode reiniciar o computador agora."
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
