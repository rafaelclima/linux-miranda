````md
# 🚀 Guia Completo — Linux no Domínio MIRANDA.BR

**✅ Funcionalidades:**
- Login com **usuário AD**
- Geração automática do **ticket Kerberos (TGT)**
- Montagem automática do `\\berlim\\Dbclipper` em `/mnt/Publico` via `autofs` + `sec=krb5`
- Criação de atalho na Área de Trabalho **para abrir a pasta de rede**
- Sem `pam_mount`
- Sem senha para abrir o compartilhamento **se as permissões NTFS/ACLs permitirem**

---

## 📌 1️⃣ Pré-requisitos

- **AnduinOS/Ubuntu** atualizado  
- Rede corporativa **Active Directory MIRANDA.BR**  
- Servidores DNS internos:
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

Exemplo:

```conf
nameserver 192.168.10.240
nameserver 192.168.10.241
search miranda.br
```

**Teste resolução:**

```bash
nslookup berlim.miranda.br
```

---

## 📦 4️⃣ Instale pacotes necessários

```bash
sudo apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit krb5-user cifs-utils gvfs-backends gvfs-fuse libpam-krb5 autofs
```

✅ Inclui tudo para:

- `realm` (ingresso)
- `sssd` (cache + auth)
- `krb5`
- `autofs` (montagem automática)
- `cifs-utils` (SMB + Kerberos)
- `gvfs` (Nautilus `smb://`)

---

## 🔑 5️⃣ Configure o Kerberos

```bash
sudo nano /etc/krb5.conf
```

Exemplo:

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

Teste:

```bash
kinit Administrador@MIRANDA.BR
klist
```

---

## 🏷️ 6️⃣ Ingressar no domínio

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

Exemplo seguro e funcional:

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

**Permissões:**

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd
```

Teste resolução:

```bash
id seu_usuario@miranda.br
```

---

## 🏠 8️⃣ Criação automática de HOME

Habilite:

```bash
sudo pam-auth-update --enable mkhomedir
```

Verifique `/etc/pam.d/common-session` → deve conter:

```conf
session required pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

---

## 🔒 9️⃣ Configure PAM para autenticação AD

Garanta que `common-auth` e `common-account` têm blocos `pam_sss.so`:

### `/etc/pam.d/common-auth`

```conf
auth    [success=2 default=ignore]      pam_unix.so nullok
auth    [success=1 default=ignore]      pam_sss.so use_first_pass
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so
auth    optional                        pam_cap.so
```

### `/etc/pam.d/common-account`

```conf
account [success=1 new_authtok_reqd=done default=ignore] pam_unix.so
account requisite                       pam_deny.so
account required                        pam_permit.so
account sufficient                      pam_localuser.so
account [default=bad success=ok user_unknown=ignore] pam_sss.so
```

---

## 🗂️ 🔟 Crie ponto de montagem

```bash
sudo mkdir -p /mnt/Publico
sudo chown root:root /mnt/Publico
sudo chmod 755 /mnt/Publico
```

---

## 🔄 1️⃣1️⃣ Configure `autofs` para montar `Dbclipper`

Edite `/etc/auto.master`:

```bash
sudo nano /etc/auto.master
```

Adicione:

```conf
/mnt/Publico  /etc/auto.dbclipper  --timeout=60 --ghost
```

Crie `/etc/auto.dbclipper`:

```bash
sudo nano /etc/auto.dbclipper
```

Conteúdo:

```conf
Dbclipper -fstype=cifs,sec=krb5,vers=3.0,cruid=%(UID) ://berlim/Dbclipper
```

Reinicie e habilite:

```bash
sudo systemctl restart autofs
sudo systemctl enable autofs
```

---

## ✅ 1️⃣2️⃣ Garanta que o Kerberos sempre use o cache certo

Adicione no `.bashrc` **do skeleton**:

```bash
sudo nano /etc/skel/.bashrc
```

No final:

```bash
# Garante cache Kerberos por UID
export KRB5CCNAME=/tmp/krb5cc_$(id -u)
```

---

## 🏷️ 1️⃣3️⃣ Script para atalho na Área de Trabalho

Crie:

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
Name=Publico_Miranda
Icon=folder-remote
Exec=nautilus /mnt/Publico/Dbclipper
Terminal=false
EOF

  chmod +x "$SHORTCUT"
  gio set "$SHORTCUT" "metadata::trusted" yes 2>/dev/null || true
fi
```

Permissões:

```bash
sudo chmod +x /usr/local/bin/cria_atalho_dbclipper.sh
```

---

## 🏷️ 1️⃣4️⃣ Execute o script no login

Adicione ao `.profile` do skeleton:

```bash
sudo nano /etc/skel/.profile
```

No final:

```bash
# Cria atalho na Área de Trabalho
/usr/local/bin/cria_atalho_dbclipper.sh
```

Assim, **todo novo HOME** herda isso.

---

## ✅ 1️⃣5️⃣ Teste

1️⃣ Login com usuário AD\
2️⃣ `klist` → deve ter `krbtgt`\
3️⃣ `ls /mnt/Publico/Dbclipper` → deve listar sem senha\
4️⃣ Atalho criado na Área de Trabalho → abre com Nautilus

---

## ⚠️ Atenção extra

- **Não precisa dar root para usuários** → permissões `755` cuidam disso.
- Garantir que o **compartilhamento **`` aceite **Kerberos (**``**)**.
- Teste permissões NTFS/ACL para evitar `Permission Denied`.

---

## 🎉 Pronto

**➡️ Login, ticket Kerberos, montagem automática, sem senha e atalho pronto.**\
**Nada de **``**, tudo **``** + **``**.**

```
```
