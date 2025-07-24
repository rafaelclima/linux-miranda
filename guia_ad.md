# 🚀 Guia Completo — Linux no Domínio MIRANDA.BR

Este guia é um passo a passo **completo**, pronto para ser usado como documentação em um repositório **GitHub**.

---

## 📌 1️⃣ Pré-requisitos

- Ubuntu/AnduinOS atualizado
- Active Directory MIRANDA.BR
- DNS:
  - berlim: 192.168.10.240
  - tokyo: 192.168.10.241
- Acesso sudo/root

## ⚙️ 2️⃣ Atualize o sistema

```bash
sudo apt update && sudo apt upgrade -y
```

## 🌐 3️⃣ Configure o DNS

Edite `/etc/resolv.conf`:

```conf
nameserver 192.168.10.240
nameserver 192.168.10.241
search miranda.br
```

Teste:

```bash
nslookup berlim.miranda.br
```

## 📦 4️⃣ Instale pacotes necessários

```bash
sudo apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit krb5-user cifs-utils gvfs-backends gvfs-fuse libpam-krb5 autofs
```

## 🔑 5️⃣ Configure o Kerberos

Edite `/etc/krb5.conf`:

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

## 🏷️ 6️⃣ Ingressar no domínio

```bash
sudo realm join --verbose --user=Administrador MIRANDA.BR
realm list
```

## ⚙️ 7️⃣ Configure o SSSD

Edite `/etc/sssd/sssd.conf`:

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

Permissões:

```bash
sudo chmod 600 /etc/sssd/sssd.conf
sudo systemctl restart sssd
id almox@miranda.br
```

## 🏠 8️⃣ Criação automática de HOME

```bash
sudo pam-auth-update --enable mkhomedir
```

Verifique `/etc/pam.d/common-session`:

```conf
session required pam_mkhomedir.so skel=/etc/skel/ umask=0077
```

## 🔒 9️⃣ Configure PAM

```conf
# /etc/pam.d/common-auth
auth    [success=1 default=ignore]      pam_unix.so nullok  
auth    [success=2 default=ignore]      pam_krb5.so use_first_pass  
auth    [success=1 default=ignore]      pam_sss.so use_first_pass  
auth    requisite                       pam_deny.so  
auth    required                        pam_permit.so
```
---

```conf
# /etc/pam.d/common-auth

# Primeiro tenta autenticar local (usuário local /etc/shadow)
auth    [success=2 default=ignore] pam_unix.so nullok

# Se local falhar, tenta pegar TGT do Kerberos usando mesma senha
auth    [success=1 default=ignore] pam_krb5.so use_first_pass

# Se Kerberos falhar, tenta resolver via SSSD (AD)
auth    [success=1 default=ignore] pam_sss.so use_first_pass

# Se tudo falhar, bloqueia
auth    requisite pam_deny.so

# Permite passar se algum módulo anterior aceitou
auth    required pam_permit.so

# Opcional — capabilities
auth    optional pam_cap.so

```
---

```conf
# /etc/pam.d/common-session

# Padrão do sistema
session required pam_unix.so

# Cria HOME automático com base no skel
session required pam_mkhomedir.so skel=/etc/skel/ umask=0077

# Garante ticket Kerberos no session (opcional)
session optional pam_krb5.so

# Garante cache do SSSD
session optional pam_sss.so

# Outros módulos padrão
session optional pam_systemd.so
session optional pam_loginuid.so

```

---

✅ /etc/profile.d/auto-kinit.sh (opcional, extra-cautela)

Crie:
```bash
sudo nano /etc/profile.d/auto-kinit.sh
```

Conteúdo:
```conf
#!/bin/bash

# Só para usuários do domínio, para não afetar user local
if [[ "$USER" == *@MIRANDA.BR ]]; then
  # Se não houver ticket TGT, pega agora
  klist -s || kinit "$USER"
fi
```

Permissão:
```bash
sudo chmod +x /etc/profile.d/auto-kinit.sh
```

## 🗂️ 🔟 Crie ponto de montagem

```bash
sudo mkdir -p /mnt/Publico
sudo chown root:root /mnt/Publico
sudo chmod 755 /mnt/Publico
```

## 🔄 1️⃣1️⃣ Configure autofs

Edite `/etc/auto.master`:

```conf
/mnt/Publico  /etc/auto.dbclipper  --timeout=60 --ghost
```

Crie `/etc/auto.dbclipper`:

```conf
Dbclipper -fstype=cifs,sec=krb5,vers=3.0,cruid=%(UID) ://berlim/Dbclipper
```

Reinicie:

```bash
sudo systemctl restart autofs
sudo systemctl enable autofs
```

## ✅ 1️⃣2️⃣ Configure bashrc

Edite `/etc/skel/.bashrc`:

```bash
export KRB5CCNAME=/tmp/krb5cc_$(id -u)
```

## 🏷️ 1️⃣3️⃣ Crie script do atalho

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

Permissão:

```bash
sudo chmod +x /usr/local/bin/cria_atalho_dbclipper.sh
```

## 🏷️ 1️⃣4️⃣ Execute script no login

Edite `/etc/skel/.profile`:

```bash
/usr/local/bin/cria_atalho_dbclipper.sh
```

## ✅ 1️⃣5️⃣ Teste tudo

1️⃣ Login com usuário AD\
2️⃣ Verifique `klist`\
3️⃣ Verifique `/mnt/Publico/Dbclipper`\
4️⃣ Confirme atalho na Área de Trabalho

## 🎉 Pronto!

