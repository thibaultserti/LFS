#!/bin/bash

echo "Bienvenue dans l'assistant d'installation de Linux From Scratch LFS"
if [ `bash version-check.sh | tail -n 1 | cut -d ' ' -f3-` != "OK" ]; 
then
echo "Le système hôte n'a pas les prérequis nécessaires ! Vous pouvez lancez la commande bash version-check.sh pour essayer de comprendre d'où vient le problème !"
exit 1
fi
echo "Choisissez la partition d'installation de LFS"

isNotOk=false
while is_not_ok;
do
sudo fdisk -l | tail -n +10 | head -n -2 
echo "Quel partition voulez vous utiliser pour LFS ? (ATTENTION : toutes les données déjà présentes sur le disque seront effacées ! (Taper /dev/sdxx)"
read partition ;
done

if [ partition != "/dev/sd"* ]
then
echo "Partition invalide !"
exit 1
fi

mkfs -v -t ext4 $partition
echo "export LFS=/mnt/lfs" >> $HOME/.bashrc

