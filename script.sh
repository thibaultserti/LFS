#!/bin/bash

# ------ PRÉREQUIS --------------
echo "Bienvenue dans l'assistant d'installation de Linux From Scratch LFS"
if [ `bash version-check.sh | tail -n 1 | cut -d ' ' -f3-` != "OK" ]; 
then
    echo "Le système hôte n'a pas les prérequis nécessaires ! Vous pouvez lancez la commande bash version-check.sh pour essayer de comprendre d'où vient le problème !";
    exit 1;
fi

bash version-check.sh
echo "Êtes vous sûr de vouloir continuer (o/N) ?"
read val
if [ $val != "o" ];
then
    exit 1
fi

# ------ PARTITIONNEMENT ---------
echo "Choisissez la partition d'installation de LFS"

while [ true ];
do
    sudo fdisk -l | tail -n +10 | head -n -2 
    echo "Quelle partition voulez vous utiliser pour LFS ? (ATTENTION : toutes les données déjà présentes sur le disque seront effacées ! (Taper /dev/sdxx)"
    read partition
    if ! [[ $partition =~ /dev/sd[a-f][1-9] ]];
    then
        echo "Partition invalide !";
    else
        break;
    fi
done



mkfs -v -t ext4 $partition
echo "export LFS=/mnt/lfs" >> $HOME/.bashrc
export LFS=/mnt/lfs

mkdir -pv $LFS
sleep 1;
mount -v -t ext4 $partition $LFS


# ------- PAQUETS ------------
echo "Nous allons maintenant télécharger les paquets"

mkdir -v $LFS/sources
chmod -v a+wt $LFS/sources
echo "Téléchargement en cours ... "
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
cp md5sums $LFS/sources
pushd $LFS/sources
if [ `(md5sum -c md5sums | tail -n 1 | cut -d ':' -f2)` != "Success" ] && [ `(md5sum -c md5sums | tail -n 1 | cut -d ':' -f2)` != "Réussi" ];
then 
    echo "Les sommes de contrôles md5 ne correspondent pas !" ;
    popd ;
    exit 1
fi

popd

# ------------- RÉPERTOIRE TOOLS ----------
mkdir -v $LFS/tools
ln -sv $LFS/tools /

# ------------ UTILISATEUR LFS ------------

groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
echo "Définissez un mot de passe pour l'utilisateur LFS :"
passwd lfs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources


su lfs -c 'cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF'

su lfs -c 'cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
export LFS="/mnt/lfs"
EOF'


while [ true ];
do
    echo "Combien avez vous de coeurs sur votre processeur ? (Tapez 1 si vous ne savez pas) ";
    read nb_cores;

    re='^[0-9]+$';
    if ! [[ $nb_cores =~ $re ]] ; then
        echo "Ceci n'est pas un nombre entier !";
    
    else
        break;
    fi
    
done

echo "export MAKEFLAGS=-j $nb_cores" >> /home/lfs/.bashrc


#su lfs -c 'source ~/.bash_profile'
