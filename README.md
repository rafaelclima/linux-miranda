
<h1 align="center">🚀 Guia de Instalação e Configuração - Linux Mint Miranda</h1>

Este guia ajuda a instalar e configurar o **Linux Mint**, ou outras distribuições Linux baseadas em **Debian**, com o **Navegador Sankhya**, softwares essenciais e integração ao **AD MIRANDA.BR** com mapeamento automático de pastas de rede.  
➡️ **Siga os passos na ordem correta para garantir o sucesso da configuração!** 😉

<p align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/3/35/Tux.svg" alt="Linux Logo" width="200" style="margin-right: 140px;"/>
  <img src="https://lh3.googleusercontent.com/d/1gVGI0GgiIywENstJnNwp_kqD1DG3kNfv" alt="Logo Miranda" width="240"/>
</p>

---

## 📑 Sumário

1. [Instalação do Navegador Sankhya](#-1-instalação-do-navegador-sankhya)  
2. [Compartilhamento de Rede](#-2-compartilhamento-de-rede)  
3. [Criar Atalho para Ramais Miranda](#-3-criar-atalho-para-ramais-miranda)  
4. [Programas Extras](#-4-programas-extras)  
5. [Ingressar no Domínio AD MIRANDA.BR](#-5-ingressar-no-domínio-ad-mirandabr)  
6. [Aplicar Wallpaper Miranda](#-6-aplicar-wallpaper-miranda-para-todos-os-usuários)  
7. [Finalização](#-7-finalização)  
8. [Conclusão](#-conclusão)  

---

## 📂 1) Instalação do Navegador Sankhya

*(mesma configuração anterior)*

---

## 🌐 2) Compartilhamento de Rede

### 📌 Montagem Automática com pam_mount
Edite o arquivo `shares.xml` na pasta `\\berlim\NETLOGON\cid` e adicione (se não existir):

```xml
<pam_mount>
  <debug enable="0" />
  <mkmountpoint enable="1" remove="true" />
  <logout wait="0" hup="yes" term="yes" kill="yes" />

  <volume sgrp="gloja 5" fstype="cifs" server="berlim" path="Dbclipper\PESSOAL" mountpoint="~/Publico_LJ05" />
  <volume sgrp="gloja 1" fstype="cifs" server="berlim" path="01" mountpoint="~/Publico_LJ01" />
  <volume sgrp="gloja 2" fstype="cifs" server="berlim" path="02" mountpoint="~/Publico_LJ02" />
  <volume sgrp="gloja 7" fstype="cifs" server="berlim" path="07" mountpoint="~/Publico_LJ07" />
  <volume sgrp="gloja 8" fstype="cifs" server="berlim" path="08" mountpoint="~/Publico_LJ08" />
  <volume sgrp="gloja 11" fstype="cifs" server="berlim" path="11" mountpoint="~/Publico_LJ011" />
</pam_mount>
```

🔒 Isso garante que as pastas de rede sejam montadas automaticamente para usuários do AD de acordo com seus grupos.

---

### 📌 Criar Atalho Automático na Área de Trabalho
Para que cada pasta montada apareça automaticamente na **Área de Trabalho** do usuário, crie o script abaixo:

```bash
sudo nano /etc/profile.d/cria_atalhos.sh
```

Conteúdo:

```bash
#!/bin/bash

USER_HOME="/home/$USER/Desktop"

# Garante que a pasta Desktop existe
mkdir -p "$USER_HOME"

# Cria atalhos para cada pasta Publico_* montada
for dir in ~/Publico_*; do
    if [ -d "$dir" ]; then
        LINK_NAME="$USER_HOME/$(basename "$dir").desktop"
        cat <<EOF > "$LINK_NAME"
[Desktop Entry]
Name=$(basename "$dir")
Comment=Pasta de rede
Exec=xdg-open $dir
Icon=folder
Terminal=false
Type=Application
EOF
        chmod +x "$LINK_NAME"
    fi
done
```

Dar permissão de execução:

```bash
sudo chmod +x /etc/profile.d/cria_atalhos.sh
```

✅ Agora, sempre que o usuário do AD fizer login:  
1. O `pam_mount` monta a pasta de rede correspondente ao grupo.  
2. O script cria automaticamente **um atalho na Área de Trabalho** para essa pasta.  

---

## 📞 3) Criar Atalho para Ramais Miranda

*(mantido igual ao tutorial anterior)*

---

## 🧰 4) Programas Extras

*(mantido igual ao tutorial anterior)*

---

## 🏢 5) Ingressar no Domínio AD `MIRANDA.BR`

*(mantido igual ao tutorial anterior)*

---

## 🖼️ 6) Aplicar Wallpaper Miranda para Todos os Usuários

*(mantido igual ao tutorial anterior)*

---

## ✅ 7) Finalização

Após o login de cada usuário, recomenda-se:  
- ⚡ Ajustar configurações de energia.  
- 💼 Configurar TeamViewer para não ser encerrado.  
- 🌐 Cadastrar a base de produção no Sankhya-Om.  
- 📂 Confirmar que as pastas de rede aparecem na Área de Trabalho.  

---

## 🎉 Conclusão

Parabéns! 🎊  
O ambiente Linux agora está configurado para:  
- Ingressar no AD.  
- Montar automaticamente pastas de rede de acordo com o grupo do usuário.  
- Criar atalhos dessas pastas na Área de Trabalho.  
- Aplicar os padrões visuais e de software da empresa.  

Em caso de dúvidas, entre em contato com o **time de TI** 👨‍💻💚
