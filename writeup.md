# Write up

## 1. Fichier capture.pcap

On dispose d'un fichier capture.pcap dans lequel on reconnait une transmission
TCP entre deux machines (.4.231 et .3.233) dont on va vouloir extraire le
données.

```console
/tmp $ tcpflow -a -r /tmp/capture.pcap -o /tmp/res/
/tmp $ ls -l /tmp/res
-rw-r--r-- 1 1000 1000 2,3G 13 févr. 12:57 migration.qemu
...
/tmp $ file /tmp/res/migration.qemu
res/migration.qemu: QEMU suspend to disk image
```

On sait donc qu'il s'agit d'une VM qu'il va nous falloir étudier afin d'obtenir
un maximum d'informations. On commence par lire l'entête de cette image.

```console
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
/tmp $ strings migration.qemu | grep -e "kernel: [    0.000000]"
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
/tmp $ qemu-img create -f qcow2 export/incoming.qcow2 4G
```

On lance ensuite l'hyperviseur en attente d'une migration entrante sur le port 4444.

Note: La quantité de mémoire vive est ici celle par défaut dans QEMU, mais on
pourrait la retrouver avec le swap du disque. Le cpu est inconnu mais celui par
défaut ("qemu64") fonctionne, de plus à l'aide d'un strings sur migration.qemu
on peut retrouver la trace dmesg de la VM qui nous donne l'architecture du
système.

```console
/tmp $ sudo -b qemu-system-x86_64 -enable-kvm \
    -machine "pc-i440fx-2.8" \
    -m size=128M \
    -hda export/incoming.qcow2 \
    -net "nic,model=virtio" \
    -incoming tcp:0:4444

pv /tmp/res/migration.qemu > nc localhost 4444
```

Une fois ceci fait on dispose d'un VM lancée mais à laquelle on ne peut pas se
connecter. QEMU premet via son interface monitor, d'accéder à la mémoire
physique de la VM.

Sauvegarde la RAM dans ram.raw
```console
pmemsave 0 0x8000000 export/ram.raw
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
`migration.qemu`.

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

```console
include solving script
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
/tmp.

Après étude du programme (désassemblage, débogueur, reverse...) on comprend que
celui-ci chiffre les documents de l'utilisateur avec une clé aléatoire de 256
bits, stockée sur le tas.

Un fois la clé obtenue on peut déchiffrer les documents à l'aide du même programme :
```console
/tmp/cryptolock -d keyfile
```

Pour retrouver la clé on a plusieurs solutions :

 * Payer la rançon aux organisateurs ;-).
 * Déboguer le programme avec GDB (celui-ci est toujours en cours d'exécution).
 * Analyser la RAM de la VM (avec volatility par exemple).
 * ...

#### Analyse mémoire avec volatility

Pour extraire le tas du programme avec volatility :

```bash
OUT="out"
PROCS="$OUT/psaux.txt"
MAPS="$OUT/proc_maps.txt"
volatility -f dump --profile=LinuxDebian87x64 linux_psaux > "$PROCS"
pid=$(grep cryptolock "$PROCS" | cut -d " " -f 1)
volatility -f dump --profile=LinuxDebian87x64 -p "$pid" linux_proc_maps > "$MAPS"
heap_base_addr=$(grep heap "$MAPS" | awk '{ print $4 }')
volatility -f dump --profile=LinuxDebian87x64 -p "$pid" linux_dump_map --vma "${heap_base_addr}" -D "$OUT/"
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
for key in $(ls /tmp/key_*)
do
    /tmp/cryptolock -d "$key"
    if [ $? -eq 0 ]
    then
        break
    fi
done
```
