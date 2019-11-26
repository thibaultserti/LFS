#!/bin/bash

echo "Bienvenue dans l'assistant d'installation de Linux From Scratch LFS"
if [ `bash version-check.sh | tail -n 1 | cut -d ' ' -f3-` != "OK" ]; 
then
echo "Le système hôte n'a pas les prérequis nécessaires ! Vous pouvez lancez la commande bash version-check.sh pour essayer de comprendre d'où vient le problème !"
exit 1
fi
