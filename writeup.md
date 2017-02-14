# Write up

## 1. Fichier capture.pcap

On dispose d'un fichier capture.pcap dans lequel on reconnait une transmission
TCP entre deux machines (.4.231 et .3.233) dont on va vouloir extraire le
données.

```console
/tmp $ tcpflow -a -r /tmp/capture.pcap -o /tmp/flow/
/tmp $ ls -l /tmp/flow
-rw-r--r-- 1 toffan users 2,3G 2017-02-13 13:02 192.168.003.233.42398-192.168.004.231.04444
-rw-r--r-- 1 toffan users  16K 2017-02-13 13:05 report.pdf
-rw-r--r-- 1 toffan users 4,1K 2017-02-13 13:05 report.xml
/tmp $ file /tmp/flow/192.168.003.233.42398-192.168.004.231.04444
/tmp/flow/capture.qemu: QEMU suspend to disk image
```

On sait donc qu'il s'agit d'une VM qu'il va nous falloir étudier afin d'obtenir
un maximum d'informations. On commence par lire l'entête de cette image.

```console
/tmp $ mv flow/192.168.003.233.42398-192.168.004.231.04444 capture.qemu
/tmp $ strings capture.qemu
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
/tmp $ strings capture.qemu | grep -e "kernel: [    0.000000]"
...
Feb  9 13:42:15 allnightlong kernel: [    0.000000] Hypervisor detected: KVM
...
```

Ces informations nous seront utiles pour configurer un hyperviseur permettant
de recevoir la VM. On sait que l'hyperviseur utilisé est QEMU d'après l'entête
du fichier. On retrouve aussi dans les logs le fait quelle tourne sur un KVM
(sans cette option l'hyperviseur ne parvient pas à lancer la VM avec une erreur
qui nous met sur la voie).

Premièrement on crée un disque suffisant pour recevoir les infos. Ici, la
capture fait environ 2G donc 4G de disque est largement suffisant.

```console
/tmp $ qemu-img create -f qcow2 incoming.qcow2 4G

/tmp $ sudo -b qemu-system-x86_64 -enable-kvm \
    -machine "pc-i440fx-2.8" \
    -m size=128M \
    -hda export/incoming.qcow2 \
    -net "nic,model=virtio" \
    -incoming tcp:0:4444

pv /tmp/res/capture.qemu > nc localhost 4444
```

On lance ensuite l'hyperviseur en attente d'une migration entrante sur le port
4444.

Note: La quantité de mémoire vive est ici celle par défaut dans QEMU, mais on
pourrait la retrouver avec le swap du disque. Le cpu est inconnu mais celui par
défaut ("qemu64") fonctionne, de plus à l'aide d'un strings sur capture.qemu
on peut retrouver la trace dmesg de la VM qui nous donne l'architecture du
système.

Une fois ceci fait on dispose d'un VM lancée mais à laquelle on ne peut pas se
connecter. QEMU premet via son interface monitor, d'accéder à la mémoire
physique de la VM.

Sauvegarde la RAM dans ram.raw
```console
pmemsave 0 0x8000000 ram.raw
```

On a aussi accès au disque incoming.qcow2 que l'on peut monter et analyser de
notre côté. (on peut aussi relancer la VM avec une liveUSB branchée).

```console
# Mount disk partition
sudo modprobe nbd
sudo qemu-nbd -c /dev/nbd0 "${DEST}/allnightlong-work.qcow2"
sudo kpartx -a -v /dev/nbd0 \
&& sleep 0.5 # prevent a race condition
sudo mount /dev/mapper/nbd0p2 mnt

ls mnt/root/
flag-1.gz   flag-2.gz   flag-3.gz
gzip -c flag-*.gz
THCon{aaaa
aaaaaaaaaa
aaaaaa}
```

Si l'on souhaite travailler directement sur la VM nous avons plusieurs possibilités :

 * On a accès au disque donc on peut essayer de bruteforcer les mots de passe des différents utilisateurs.
 * On peut aussi modifier le disque pour activer la connexion sans mot de passe,
   ou encore ajouter notre clé publique dans le fichier `.ssh/authorized_keys` des différents utilisateurs.

Afin de modifier le disque en gardant la machine virtuelle dans l'état dans
lequel on l'a reçue on peut réaliser un snapshot / migration de la VM sans le
contenu du disque et le sauver dans un fichier.

Pour réaliser le snapshot, on utilise l'interface monitor de QEMU :
```console
# Listen on port 4444 and save to snapshot.qemu.
nc -l 4444 | pv > snapshot.qemu &
# Start to send the snapshot.
migrate tcp:localhost:4444
```

On peut ensuite éteindre la VM le temps d'effectuer les modifications
nécessaires sur le disque `incoming.qcow2` (changer les mots de passe, ajouter
sa clé SSH...).

Pour redémarrer la VM dans son état d'origine on réutilise le même script que
précédemment sauf qu'on envoie le fichier `snapshot.qemu` au lieu de
`capture.qemu`.

On peut ensuite se connecter sur les différents utilisateurs de la VM :

 * root
 * rdash
 * gru

## 2. Stéganographie

On trouve dans le home de l'utilisateur `rdash` un fichier flag.gpg chiffré en
RSA.

```console
$ file flag.gpg
flag.gpg: PGP RSA encrypted session key - keyid: A45C076C 902BEC95 RSA (Encrypt or Sign) 2048b .
```

Grâce à une série d'indices on sait que l'on cherche que la clé gpg est cachée
quelque part sur le disque. On trouve dans `/usr/local/bin` un programme `hide`
dont la doc nous indique qu'il permet de cacher un fichier dans une image.

On peut donc soit désassembler le programme , soit l'utiliser sur des fichiers
connus pour savoir comment il cache les informations. On peut donc écrire un
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

Il reste ensuite à trouver
dans quelle image la clé a été cachée. Le fichier
`~/Pictures/Wallpapers/wallpaper.png` est étrange car il définit un fond
d'écran alors qu'il n'y a pas de serveur graphique d'installé.

De ce fichier on peut donc en extraire la clé et par conséquent déchiffrer le
flag.

Problème:
- Le programme `hide` est beaucoup trop simple à reverser.
- Essayer d'extraire des infos de tous les fichiers est beaucoup trop simple.

## 3. Forensic

#### Programme malveillant

On remarque que l'ensemble des fichiers dans le home de l'utilisateur gru sont
illisibles alors qu'il s'agit normalement de vidéos mp4 (d'après l'extension).

On remarque également un programme `cryptolock` en cours d'éxécution, lancé par
l'utilisateur `gru`. À l'aide d'un `find` on apprend que ce programme est dans
`/tmp`.

Après étude du programme (désassemblage, débugger, reverse...) on comprend que
celui-ci chiffre les documents de l'utilisateur avec une clé aléatoire de 256
bits, stockée sur le tas, et envoyée sur le réseau.

Un fois la clé obtenue on peut déchiffrer les documents à l'aide du même programme :
```console
/tmp/cryptolock -d keyfile
```

Notre objectif est donc de retrouver cette clé. Pour ce faire, on a plusieurs
solutions :
- Payer la rançon aux organisateurs ;-).
- Déboguer le programme avec GDB (celui-ci est toujours en cours d'exécution).
- Analyser la RAM de la VM (avec volatility par exemple).
- ...

#### Analyse mémoire avec volatility

Pour extraire le tas du programme avec volatility :

```bash
/tmp $ # Get the pid of cryptolock (373)
/tmp $ volatility -f dump --profile=LinuxDebian87x64 linux_psaux | grep cryptolock
373     1000    1000    /tmp/cryptolock -e

/tmp $ # Get heap location
/tmp $ volatility -f dump --profile=LinuxDebian87x64 -p 373 linux_proc_maps | grep heap
0xffff880007636ba0      373 cryptolock           0x0000000001b86000 0x0000000001bc8000 rw-                   0x0      0      0          0 [heap]

/tmp $ # Dump the heap of this process
/tmp $ volatility -f dump --profile=LinuxDebian87x64 -p 373 linux_dump_map --vma 0x0000000001b86000 -D out/
```

Note : Il faut au préalable télécharger ou générer le profil volatility
correspondant (pas difficile étant donné qu'on a la VM à disposition).

Une fois le tas récupéré on peut rechercher les chaînes de 32 octets
consécutives et alignées sur 8 octets.  La clé étant uniformément aléatoire, on
peut essayer de réduire le nombre de chaines en utilisant des critères
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

D'autres solutions plus performantes doivent exister (par exemple chercher
l'adresse de la clé dans les variables de la fonction main sur la pile).

Une fois les clés potentielles stockées dans des fichiers (environ une
centaine) on peut faire un script qui les teste une à une.

```bash
for key in /tmp/key_*; do
    if /tmp/cryptolock -d "$key"; then
        break
    fi
done
```

### Solution avec gdb

En se connectant sur la VM sans la redémarrer on trouve un processus
`cryptolock` de PID 373. On trouve cet exécutable dans `/tmp/`
```console
root@allnightlong:~# ps aux
...
gru        373  0.0  2.4  10500  2952 ?        Ss   12:55   0:02 /tmp/cryptolock -e
...
root@allnightlong:~# find / -name "cryptolock"
/tmp/cryptolock
```

On peut ensuite récupérer le fichier en local et reverser le programme
```console
root@allnightlong:~# apt install gdb
root@allnightlong:~# gdbserver localhost:1111 -attach 373

~ $ gdb /tmp/cryptolock
gdb-peda$ target remote 10.0.2.2:1111
```

Après un peu de reverse on remarque que la clé de chiffrement est dans le heap
et n'est `free()` qu'après le `sleep()`, elle est donc encore présente dans le
programme. On va donc pouvoir la retrouver dans la pile. Pour cela on regarde on
cherche dans la pile une adresse pointant vers le heap dont on a l'intervalle
dans le mapping du processus.
```console
root@allnightlong:~# grep "[heap]" /proc/373/maps
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

root@allnightlong:~# echo '4cdf7d976a2c97c26d959426b0255965710a813855f6652d0dc34244dd7b524f' \
| xxd -r -p > /tmp/key
root@allnightlong:~# sudo -u gru /tmp/cryptolock -d /tmp/key
```

On récupère ainsi le home de `gru` et le flag présent à la fin de la vidéo
`Carte_Kiwi.mp4`.
