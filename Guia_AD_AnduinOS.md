
# 🚀 Guia Completo — Integração AnduinOS (Ubuntu-based) no Active Directory MIRANDA.BR

Este guia ensina **passo a passo** como:

✅ Integrar máquinas **Linux** ao **AD Windows Server**  
✅ Permitir login de usuários do AD **sem erros de GPO**  
✅ Gerar **ticket Kerberos** no login (SSO real)  
✅ Criar **automático** um atalho na **Área de Trabalho** que abre o compartilhamento `Dbclipper`  
✅ Sem `pam_mount` (montagem automática não confiável removida)  

---

## 📌 1️⃣ Pré-Requisitos

- **AnduinOS** (base Ubuntu) atualizado
- Rede corporativa com **Active Directory** (ex: `miranda.br`)
- Servidores DNS configurados:
  - **berlim**: `192.168.10.240`
  - **tokyo**: `192.168.10.241`
- Acesso **sudo/root** no Linux

---

## ⚙️ 2️⃣ Atualize o sistema

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 🌐 3️⃣ Configure o DNS

Edite `/etc/resolv.conf`:

```bash
sudo nano /etc/resolv.conf
```

Conteúdo exemplo:

```conf
nameserver 192.168.10.240
nameserver 192.168.10.241
search miranda.br
```

**Teste se o DNS resolve:**

```bash
nslookup berlim.miranda.br
```

---

## 📦 4️⃣ Instale pacotes necessários

```bash
sudo apt install -y realmd sssd sssd-tools libnss-sss libpam-sss libpam-mount adcli samba-common-bin oddjob oddjob-mkhomedir packagekit krb5-user cifs-utils gvfs-backends gvfs-fuse gvfs-smb libpam-krb5
```

✅ Inclui tudo para:
- `realm`
- `sssd`
- `krb5`
- **Nautilus + gvfs-smb** para abrir `smb://` direto

---

## 🔑 5️⃣ Configure o Kerberos

Edite `/etc/krb5.conf`:

```bash
sudo nano /etc/krb5.conf
```

Conteúdo:

```ini
[libdefaults]
default_realm = MIRANDA.BR
dns_lookup_realm = false
dns_lookup_kdc = false
ticket_lifetime = 24h
forwardable = true
rdns = false

[realms]
MIRANDA.BR = {
  kdc = berlim.miranda.br
  kdc = tokyo.miranda.br
  admin_server = berlim.miranda.br
}

[domain_realm]
.miranda.br = MIRANDA.BR
miranda.br = MIRANDA.BR
```

---

## 🏷️ 6️⃣ Junte o Linux ao domínio

```bash
sudo realm join --verbose --user=Administrador MIRANDA.BR
```

Verifique:

```bash
realm list
```

---

## ⚙️ 7️⃣ Configure o SSSD

```bash
sudo nano /etc/sssd/sssd.conf
```

Exemplo **pronto**:

```ini
[sssd]
domains = miranda.br
config_file_version = 2
services = nss, pam

[domain/miranda.br]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = MIRANDA.BR
realmd_tags = manages-system joined-with-adcli
id_provider = ad
access_provider = ad
fallback_homedir = /home/%u@%d
ad_domain = miranda.br
use_fully_qualified_names = True
ldap_id_mapping = True
ad_gpo_ignore_unreadable = True
```

**Corrija permissões:**

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd
```

---

## ✅ 8️⃣ Verifique se o usuário resolve

```bash
id almox@miranda.br
```

Deve mostrar UID/GID.

---

## 🏠 9️⃣ Configure criação automática de `home`

Edite `/etc/pam.d/common-session`:

```bash
sudo nano /etc/pam.d/common-session
```

Garanta que contém:

```conf
session [default=1]                     pam_permit.so
session requisite                       pam_deny.so
session required                        pam_permit.so
session optional                        pam_umask.so
session required                        pam_unix.so
session optional                        pam_sss.so
session optional                        pam_mount.so
session optional                        pam_systemd.so
session required                        pam_mkhomedir.so skel=/etc/skel/ umask=0077

```

```bash
sudo nano /etc/pam.d/common-auth
```

Garanta que contém:

```conf
auth    [success=2 default=ignore]      pam_unix.so nullok
auth    [success=1 default=ignore]      pam_sss.so use_first_pass

auth    requisite                       pam_deny.so
auth    required                        pam_permit.so

auth    optional                        pam_cap.so
```

```bash
sudo nano /etc/pam.d/common-account
```

Garanta que contém:

```conf
account [success=1 new_authtok_reqd=done default=ignore] pam_unix.so
account requisite                       pam_deny.so
account required                        pam_permit.so
account required                        pam_unix.so
account sufficient                      pam_localuser.so
account [default=bad success=ok user_unknown=ignore] pam_sss.so
```

---

## 🔑 🔐 1️⃣0️⃣ Garanta geração automática do ticket Kerberos

Edite `/etc/pam.d/common-auth`:

```bash
sudo nano /etc/pam.d/common-auth
```

Garanta:

```conf
auth [success=1 default=ignore] pam_sss.so use_first_pass
auth [success=1 default=ignore] pam_krb5.so use_first_pass
```

E em `/etc/pam.d/common-session`:

```bash
session optional pam_krb5.so
```

---

## 🗂️ 1️⃣1️⃣ Crie o script de atalho `Dbclipper`

📂 Crie `/usr/local/bin/cria_atalho_dbclipper.sh`:

```bash
sudo nano /usr/local/bin/cria_atalho_dbclipper.sh
```

Conteúdo:

```bash
#!/bin/bash

DESKTOP_DIR="$HOME/Desktop"
SHORTCUT="$DESKTOP_DIR/Dbclipper.desktop"

mkdir -p "$DESKTOP_DIR"

if [ ! -f "$SHORTCUT" ]; then
  cat << EOF > "$SHORTCUT"
[Desktop Entry]
Version=1.0
Type=Application
Name=Dbclipper
Icon=folder-remote
Exec=nautilus smb://berlim.miranda.br/Dbclipper
Terminal=false
EOF

  chmod +x "$SHORTCUT"
  gio set "$SHORTCUT" "metadata::trusted" yes 2>/dev/null || true
fi
```

💾 **Salve e torne executável:**

```bash
sudo chmod +x /usr/local/bin/cria_atalho_dbclipper.sh
```

---

## 🗂️ 1️⃣2️⃣ Rode o script no login

Edite `/etc/skel/.profile`:

```bash
sudo nano /etc/skel/.profile
```

Adicione **no final**:

```bash
# Cria atalho Dbclipper na Área de Trabalho
/usr/local/bin/cria_atalho_dbclipper.sh
```

Assim, **todo novo usuário** terá o `.profile` que executa o script **automaticamente**.

---

## ✅ 1️⃣3️⃣ Teste tudo

1️⃣ Faça logout.  
2️⃣ Logue com um usuário do AD.  
3️⃣ Verifique com `klist` → deve ter `krbtgt`.  
4️⃣ Verifique se o atalho está na Área de Trabalho.  
5️⃣ Clique → `Dbclipper` abre **sem pedir senha** (se ticket válido).

---

## 🛡️ 1️⃣3️⃣ (Opcional) Bloquear dispositivos USB

```bash
sudo nano /etc/udev/rules.d/100-no-usb.rules
```

Conteúdo:

```conf
SUBSYSTEM=="usb", ATTR{authorized}="0"
```

Recarregue regras:

```bash
sudo udevadm control --reload
```

---

## 🎉 Pronto!

✅ Linux no domínio  
✅ Login com AD **sem erros de GPO**  
✅ Ticket Kerberos gerado **automaticamente**  
✅ Atalho `Dbclipper` criado toda vez que loga  
✅ `Nautilus` abre `smb://` **direto** sem `pam_mount` nem `fstab`

---

## 📄 Autor: Rafael Lima 🧑‍💻  
**📅 Revisado:** Julho/2025
