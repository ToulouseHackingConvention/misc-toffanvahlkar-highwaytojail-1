# Write up

## 1. Capture Réseau

On dispose d'un fichier capture.pcap dans lequel on reconnait une transmission
TCP entre deux machines (.1.2 et .1.6) dont on va vouloir extraire le
données.

```console
/tmp $ tcpflow -a -r capture.pcap -o flow/
/tmp $ ls -lh flow
-rw-r--r-- 1 volodia volodia 2,3G  3 mars  17:41 **192.168.001.002.52838-192.168.001.006.04444**
-rw-r--r-- 1 volodia volodia  16K 11 mars  00:25 report.pdf
-rw-r--r-- 1 volodia volodia 4,1K 11 mars  00:25 report.xml
/tmp $ file flow/***192.168.001.002.52838-192.168.001.006.04444*
flow/192.168.001.002.52838-192.168.001.006.04444: QEMU suspend to disk image
```

Après quelques recherches on apprend qu'il s'agit d'une live migration de VM,
que nous allons essayer de lancer afin d'obtenir un maximum d'informations. On
commence par lire l'entête de cette image.

```console
/tmp $ mv flow/***192.168.001.002.52838-192.168.001.006.04444* migration.qemu
/tmp $ strings migration.qemu
QEVM
pc-i440fx-2.8       # machine
block
pc.ram
vga.vram
/rom@etc/acpi/tables
pc.bios
0000:00:03.0/virtio-net-pci.rom     # network card
pc.rom
0000:00:02.0/vga.rom
/rom@etc/table-loader
/rom@etc/acpi/rsdp
ide0-hd0    # HDD
...         # MBR
GRUB        # GRUB
...
/tmp $ strings migration.qemu | grep "kernel: \[    0\.000000\]"
...
Feb 14 17:04:07 severus kernel: [    0.000000] Hypervisor detected: KVM
...
```

Ces informations nous seront utiles pour configurer un hyperviseur permettant
de recevoir la VM. On sait que l'hyperviseur utilisé est QEMU d'après l'entête
du fichier. On retrouve aussi dans les logs le fait quelle tourne sur un KVM
(sans cette option l'hyperviseur ne parvient pas à lancer la VM avec une erreur
qui nous met sur la voie).

Premièrement on crée un disque dur virtuel pour recevoir les infos. Ici, la
capture fait environ 2G donc 4G de disque est largement suffisant.

```console
/tmp $ qemu-img create -f qcow2 incoming.qcow2 4G
```

Toujours à l'aide de strings, on recherche la séquence de démarrage du noyau
afin de déterminer la quantité de mémoire vive.

```console
/tmp $ strings migration.qemu | grep "kernel: \[    0\.000000\]"
...
Feb 14 16:53:05 severus kernel: [    0.000000] Memory: 231428K/261624K available (5247K kernel code, 947K rwdata, 1832K rodata, 1208K init, 840K bss, 30196K reserved)
...
```

On peut supposer une quantité de RAM de 256MB, de plus si l'on ne spécifie pas
la bonne quantité, QEMU retourne l'erreur suivante qui nous confirme cette
supposition.

Le cpu est inconnu mais celui par défaut ("qemu64") fonctionne, de plus à
l'aide d'un strings sur `migration.qemu` on peut retrouver la trace `dmesg` de la
VM qui nous donne l'architecture du système.

On peut ainsi lancer l'hyperviseur en attente d'une migration entrante (ici on
utilise un descripteur de fichier au lieu d'une connexion tcp.

```console
/tmp $ qemu-system-x86_64 -enable-kvm \
    -machine "pc-i440fx-2.8" \
    -m size=256M \
    -hda incoming.qcow2 \
    -net "nic,model=virtio" \
    -incoming fd:<migration.qemu
```

Note : Pour la suite du challenge il peut être utile de configurer le réseau
pour la VM. Plusieurs méthodes sont possibles. On peut se tourner vers le
module réseau `tap` de QEMU pour avoir une interface réseau commune à la VM et
à notre machine physique, avec éventuellement du NAT pour que la VM ait accès à
Internet.

Une fois ceci fait on dispose d'un VM lancée mais à laquelle on ne peut pas se
connecter. QEMU permet via son interface monitor, d'accéder à la mémoire
physique de la VM.

Sauvegarde la RAM dans ram.dump
```console
/tmp $ pmemsave 0 0x10000000 ram.dump
```

On a aussi accès au disque incoming.qcow2 que l'on peut monter et analyser de
notre côté. (on peut aussi relancer la VM avec une liveUSB branchée).

```bash
# Mount disk partition
sudo modprobe nbd
sudo qemu-nbd -c /dev/nbd0 "incoming.qcow2"
sudo kpartx -a -v /dev/nbd0 \
&& sleep 0.5 # prevent a race condition
sudo mount /dev/mapper/nbd0p2 /mnt
```

Si l'on souhaite travailler directement sur la VM nous avons plusieurs possibilités :

 * On a accès au disque donc on peut essayer d'attaquer les mots de passe des différents utilisateurs.
 * On peut aussi modifier le disque pour activer la connexion sans mot de
   passe, ou encore ajouter notre clé publique dans le fichier
   `.ssh/authorized_keys` des différents utilisateurs (nécessite un reboot de
   la machine, sans quoi le cache des fichiers en RAM n'est plus cohérent avec
   le système de fichier).

On peut ensuite se connecter sur les différents utilisateurs de la VM :

 * root
 * me

## 2. Forensic

#### Programme malveillant

On remarque que l'ensemble des fichiers dans le home de l'utilisateur `me` sont
illisibles alors qu'il s'agit normalement, d'après l'extension, de vidéos mp4,
d'images, etc.

On remarque également un programme `cryptolock` en cours d'éxécution, lancé par
l'utilisateur `me`. À l'aide d'un `find` on apprend que ce programme est dans
`/tmp`.

Après étude du programme (désassemblage, débugger, reverse...) on comprend que
celui-ci chiffre les documents de l'utilisateur avec une clé aléatoire de 256
bits, stockée sur le tas, et envoyée sur le réseau.

Un fois la clé obtenue on peut déchiffrer les documents à l'aide du même programme :
```console
$ /tmp/cryptolock -d keyfile
```

Notre objectif est donc de retrouver cette clé. Pour ce faire, on a plusieurs
solutions :
- Payer la rançon aux organisateurs ;-).
- Déboguer le programme (toujours en cours d'exécution) avec GDB, si l'on peut se connecter sur la VM sans la redémarrer.
- Analyser la RAM de la VM (avec volatility par exemple).
- ...

#### Analyse mémoire avec volatility

Pour extraire le tas du programme avec volatility :

```console
/tmp $ # Get the pid of cryptolock
/tmp $ volatility -f ram.dump --profile=LinuxDebian87x64 linux_psaux | grep cryptolock
<PID>     1000    1000    /tmp/cryptolock -e

/tmp $ # Get heap location
/tmp $ volatility -f ram.dump --profile=LinuxDebian87x64 -p <PID> linux_proc_maps | grep heap
0xffff880007636ba0      <PID> cryptolock           0x0000000001b86000 0x0000000001bc8000 rw-                   0x0      0      0          0 [heap]

/tmp $ # Dump the heap of this process
/tmp $ volatility -f ram.dump --profile=LinuxDebian87x64 -p <PID> linux_dump_map --vma 0x0000000001b86000 -D out/
```

Note : Il faut au préalable télécharger ou générer le profil volatility
correspondant (pas difficile étant donné qu'on a la VM à disposition).  Voir
https://github.com/volatilityfoundation/profiles pour les profils existants et
https://code.google.com/archive/p/volatility/wikis/LinuxMemoryForensics.wiki
pour créer un profil (pour l'archive zip, respecter l'arborescence des profils
disponibles sur le premier lien).

Une fois le tas récupéré on peut rechercher les chaînes de 32 octets
consécutives et alignées sur 8 octets.  La clé étant uniformément aléatoire, on
peut essayer de réduire le nombre de chaînes en utilisant des critères
statistiques.

On peut par exemple supposer que la clé ne contient pas deux octets identiques consécutifs.

```python
for off in range((len(heap)//16) - 1):
    display = True
    for i in range(31):
        display &= (heap[(off*0x10)+i] != heap[(off*0x10)+i+1])
    if display:
        output = open(key_path + "{0:02d}".format(keys), "wb")
        output.write(heap[(off*0x10):(off*0x10)+0x20])
        output.close()
```

Une fois les clés potentielles stockées dans des fichiers (environ 700) on peut
faire un script qui les teste une à une. Cela reste moins long que de
bruteforcer les 2^256 clés possibles ;-).

```bash
for key in /tmp/key_*; do
    if /tmp/cryptolock -d "$key"; then
        break
    fi
done
```

#### Analyse du programme avec gdb

En se connectant sur la VM sans la redémarrer on trouve un processus
`cryptolock` de PID <PID>. On trouve cet exécutable dans `/tmp/`
```console
root@severus:~# ps aux
...
me        <PID>  0.0  2.4  10500  2952 ?        Ss   12:55   0:02 /tmp/cryptolock -e
...
```

```console
root@severus:~# apt install gdb
root@severus:~# gdbserver localhost:1111 -attach <PID>

~ $ gdb /tmp/cryptolock
gdb-peda$ target remote 10.0.2.2:1111
```

On peut éventuellement récupérer le programme malveillant localement pour le
reverser.

Après un peu de reverse on remarque que la clé de chiffrement est dans le heap
et qu'elle n'est `free()` qu'après le `sleep()`, elle est donc encore présente
dans la mémoire du programme. On va donc pouvoir retrouver l'adresse de la clé
dans la pile. Pour cela on cherche dans la pile une adresse pointant vers le
heap dont on a l'intervalle dans le mapping du processus.

```console
root@severus:~# grep "[heap]" /proc/<PID>/maps
01b86000-01bc8000 rw-p 00000000 00:00 0                                  [heap]

gdb-peda$ context stack 96
...
0520| 0x7fff1a38af30 --> 0x1b9f4c0 --> 0xc2972c6a977ddf4c
...
gdb-peda$ x/32c 0x1b9f4c0
0x1b9f4c0:	0x4c	0xdf	0x7d	0x97	0x6a	0x2c	0x97	0xc2
0x1b9f4c8:	0x6d	0x95	0x94	0x26	0xb0	0x25	0x59	0x65
0x1b9f4d0:	0x71	0xa	    0x81	0x38	0x55	0xf6	0x65	0x2d
0x1b9f4d8:	0xd	    0xc3	0x42	0x44	0xdd	0x7b	0x52	0x4f

root@severus:~# echo '4cdf7d976a2c97c26d959426b0255965710a813855f6652d0dc34244dd7b524f' \
| xxd -r -p > /tmp/key
root@severus:~# sudo -u me /tmp/cryptolock -d /tmp/key
```

Remarque : La clé du challenge est différente de celle ci-dessus.

On récupère ainsi le home de `me`.  Après exploration du home, on trouve deux
logs IRC. Le plus récent nous explique pourquoi le home de `me` était chiffré
par un cryptolocker.  Le plus ancient nous donne un premier flag (dans le topic
du salon IRC) et nous donne des indices sur la suite du challenge : un document
caché dans un volume virtuel chiffré avec gpg. L'étape suivante va donc être de
retrouver la clé de déchiffrement.

## 3. Stéganographie

On trouve dans le home de l'utilisateur `me` un fichier `evidence` chiffré en
RSA.

```console
$ file evidence
evidence: PGP RSA encrypted session key - keyid: A45C076C 902BEC95 RSA (Encrypt or Sign) 2048b .
```

Grâce à une série d'indices on sait que l'on cherche que la clé gpg est cachée
quelque part sur le disque. On trouve dans `/usr/local/bin` un programme `hide`
dont la doc nous indique qu'il permet de cacher un fichier dans une image.

On peut donc soit désassembler le programme, soit l'utiliser sur des fichiers
connus pour savoir comment il cache les informations. On peut ensuite écrire un
programme qui extraira les informations du fichier.

```python
#!/usr/bin/env python

import sys
from PIL import Image

filename = sys.argv[1] if len(sys.argv) == 2 else "wallpaper.png"
img = Image.open(filename).convert('RGB')

MASK = 0x3
X, Y = img.size[0], 23

secret = []
for y in range(Y):
    for x in range(0, X, 3):
        r, _, _ = img.getpixel((x, y))
        secret.append(format(r & MASK, '02b'))
        # secret is a list of 2 bits strings. Ex: ['01', '11', '01', ...]


secret = ["".join(secret[i:i + 4]) for i in range(0, len(secret), 4)]
secret = "".join(chr(int(s, 2)) for s in secret)

print(secret)
```

Il reste ensuite à trouver dans quelle image la clé a été cachée. Le fichier
`~/Pictures/Wallpapers/wallpaper.png` est étrange car il définit un fond
d'écran alors qu'il n'y a pas de serveur graphique d'installé.

En lançant notre programme sur ce fichier on récupère une clé privée au format
texte GPG.  Cette clé nous permet de déchiffrer le volume virtuel.

Une fois le volume monté on trouve enfin le fameux document secret, le flag est
l'identifiant du document situé en haut de la page.
