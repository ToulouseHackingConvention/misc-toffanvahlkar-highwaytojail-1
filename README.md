# Highway to jail - part. 1

- Auteurs : toffan et Vahlkar
- Type : Miscellaneous

## Challenge
### Nom de production
Highway to jail - part. 1

### Descripion du challenge / Difficulté

Ce challenge se compose de deux parties.
La première partie est une épreuve d'analyse forensique.
La deuxième partie est une épreuve de stéganographie.

Sur une échelle [Facile, Moyen, Difficile, Hardcore] le chall se situe :
- Partie 1 : **Difficile**
- Partie 2 : **Moyen**

### Description participant

Service note:
> The target is a political opponent who has been spotted in demonstrations and
has been arrested several times for public disturbance and refusal to obey.  In
the framework of the war on terrorism, this individual has also been put under
strengthened surveillance because of his frequent use of cryptography.

> One of our field agents has put a network-capturing device on the desktop
computer of this individual. We have thus managed to obtain a network capture.

> For the sake of public image, we must silence this individual and put him behind
bars.  Your mission is to find something incriminating him. Anything will do.

Note de service:
> La cible est un opposant politique aperçu lors de manifestations et
plusieurs fois interpelé pour trouble à l'ordre public et refus d'obtempérer.
Dans le cadre de la lutte anti-terroriste, cet individu a également été placé
sous surveillance accrue pour usage régulier de la cryptographie.

> L'un de nos agent de terrain a posé un
dispositif de capture réseau sur l'ordinateur de bureau (desktop) de cet
individu. Nous avons ainsi obtenu une capture réseau.

> Par soucis d'image publique nous devons faire taire cet individu et le mettre
derrière les barreaux. Votre mission est de trouver de quoi l'incriminer,
n'importe quoi fera l'affaire.

### Fichiers fournis
- `capture.pcap` (md5: ...)

### Changement de flag

Dans le fichier de log `src/hackcave.log` le topic du salon IRC est le flag.
Il faut ensuite faire un `make clean && make migrate` puis refaire la capture
réseau.

### Usage

`make migrate` puis il faut effectuer la capture réseau à la main, c'est à dire
envoyer le fichier tmp/migration.qemu a un autre hôte qui écoute sur le port
4444 et qui fait la capture avec tcpdump (commande dans `bin/capture`). La
capture ne doit pas être effectuée sur l'interface locale ! Si tcpdump indique
que le kernel a laché des paquets il faut recommencer avec un buffer plus
grand.

```bash
# PROD
make export     # créer les exports ; Ne pas utiliser ! Voir ci-dessus.
make clean      # supprime les fichiers temporaires.
make clean-all      # supprime les exports et les images docker
```

### Situation

| Relecture | Construction | Test | Déploiement |
| --- | --- | --- | --- |
| toffan() | toffan() | toffan() | |
| Vahlkar() | Vahlkar() | Vahlkar () | |
| | | | |

### Tests

Des scripts de solution semi-automatiques sont disponibles dans les dossiers
`solution` de chaque dépot.
