#!/bin/bash

# ------ PRÉREQUIS --------------
echo "Bienvenue dans l'assistant d'installation de Linux From Scratch LFS"
if [ "$(bash version-check.sh | tail -n 1 | cut -d ' ' -f3-)" != "OK" ]; 
then
    echo "Le système hôte n'a pas les prérequis nécessaires ! Vous pouvez lancez la commande bash version-check.sh pour essayer de comprendre d'où vient le problème !";
    exit 1;
fi

bash version-check.sh
echo "Êtes vous sûr de vouloir continuer (o/N) ?"
read -r val
if [ "$val" != "o" ];
then
    exit 1
fi

# ------ PARTITIONNEMENT ---------
echo "Choisissez la partition d'installation de LFS"

while true ;
do
    sudo fdisk -l
    echo "Quelle partition voulez vous utiliser pour LFS ? (ATTENTION : toutes les données déjà présentes sur le disque seront effacées ! (Taper /dev/sdxx)"
    read -r partition
    if ! [[ $partition =~ /dev/sd[a-f][1-9] ]];
    then
        echo "Partition invalide !";
    else
        break;
    fi
done



mkfs -v -t ext4 "$partition"
echo "export LFS=/mnt/lfs" >> "$HOME/.bashrc"
export LFS=/mnt/lfs

mkdir -pv $LFS
sleep 1;
mount -v -t ext4 "$partition" "$LFS"


# ------- PAQUETS ------------
echo "Nous allons maintenant télécharger les paquets"

mkdir -v $LFS/sources
chmod -v a+wt $LFS/sources
echo "Téléchargement en cours ... "
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
cp md5sums $LFS/sources
pushd "$LFS/sources" || exit
if [ "$(md5sum -c md5sums | tail -n 1 | cut -d ':' -f2)" != " Success" ] && [ "$(md5sum -c md5sums | tail -n 1 | cut -d ':' -f2)" != " Réussi" ]&& [ "$(md5sum -c md5sums | tail -n 1 | cut -d ':' -f2)" != " OK" ];
then 
    echo "Les sommes de contrôles md5 ne correspondent pas !" ;
    popd || exit;
    exit 1
fi

popd || exit

# ------------- RÉPERTOIRE TOOLS ----------
mkdir -v $LFS/tools
ln -sv $LFS/tools /

# ------------ UTILISATEUR LFS ------------

groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
echo "Définissez un mot de passe pour l'utilisateur LFS :"
passwd lfs
chown -v lfs $LFS
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

#su lfs -c "bash lfs-setup.sh" | tee -a lfs-setup.log
#su lfs -c "bash lfs-user.sh" | tee -a lfs-user.log
