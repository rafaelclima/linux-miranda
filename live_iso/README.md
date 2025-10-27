Com certeza\! Documentar o processo de extração do arquivo `.squashfs` a partir da ISO Live do Systemback é uma etapa crucial.

Aqui está a documentação detalhada, perfeita para adicionar ao seu repositório do GitHub.

-----

## 5\. 🛠️ Extração do Arquivo `.squashfs` do ISO Live

O Systemback, após criar o "Live system", gera um arquivo `.iso` inicializável. Para a implantação via NFS, precisamos extrair o sistema de arquivos base contido nesse ISO, que está no formato **SquashFS**.

Este processo deve ser feito em uma máquina Linux que tenha o pacote `squashfs-tools` e o utilitário `mount` instalados (geralmente padrão).

### 5.1. Pré-requisito

Certifique-se de que as ferramentas de manipulação de imagens e SquashFS estão instaladas:

```bash
# Para sistemas baseados em Debian/Ubuntu (onde a extração será feita)
sudo apt update
sudo apt install squashfs-tools
```

### 5.2. Procedimento de Extração

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

### 5.3. Movendo para o Servidor NFS

Com o arquivo `mint-miranda.squashfs` em mãos, mova-o para o diretório de compartilhamento no seu servidor NFS (`192.168.10.225`):

```bash
# Execute este comando na máquina onde o arquivo foi extraído
# (Assumindo que o servidor NFS esteja acessível, ou use scp)
sudo cp mint-miranda.squashfs /caminho/do/seu/ponto/de/montagem/nfs/backups/
# OU
scp mint-miranda.squashfs usuario@192.168.10.225:/srv/nfs/backups/
```

O arquivo agora está pronto para ser acessado pelo script `Instalador.sh` na máquina cliente via rede.
