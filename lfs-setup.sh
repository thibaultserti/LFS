#!/bin/bash

cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > /home/lfs/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
export LFS="/mnt/lfs"
EOF


while true;
do
    echo "Combien avez vous de coeurs sur votre processeur ? (Tapez 1 si vous ne savez pas) ";
    read -r nb_cores;

    re='^[0-9]+$';
    if ! [[ $nb_cores =~ $re ]] ; then
        echo "Ceci n'est pas un nombre entier !";
    
    else
        break;
    fi
    
done

echo "export MAKEFLAGS='-j $nb_cores'" >> /home/lfs/.bashrc
