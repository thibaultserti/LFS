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

echo "export MAKEFLAGS='-j $nb_cores'" >> /home/lfs/.bashrc


#su lfs -c 'source ~/.bash_profile'

# ------------ COMPILATION ------------

# On assure la propreté de la chaîne d'outil

case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac

# BINUTILS (27s)
echo "Compilation de BINUTILS ... 
(le temps renvoyé à la fin est une unité caractéristique appelé SBU qui servira d'indicateur pour le temps de compilation des paquets suivants)"
su lfs -c 'tar -xf binutils-2.32.tar.xz'
cd binutils-2.32/

mkdir -v build
cd build/

su lfs -c 'time { 
    ../configure --prefix=/tools
    --with-sysroot=$LFS
    --with-lib-path=/tools/lib
    --target=$LFS_TGT
    --disable-nls
    --disable-werror
    && make 
    && make install; }'

cd $LFS/source/
rm -rf binutils-2.32$

# GCC

echo "Compilation de GCC ..."
su lfs -c 'tar -xf gcc-9.2.0.tar.xz'
cd gcc-9.2.0/

su lfs -c 'tar -xf ../mpfr-4.0.2.tar.xz'
su lfs -c 'mv -v mpfr-4.0.2 mpfr'
su lfs -c 'tar -xf ../gmp-6.1.2.tar.xz'
su lfs -c 'mv -v gmp-6.1.2 gmp'
su lfs -c 'tar -xf ../mpc-1.1.0.tar.gz'
su lfs -c 'mv -v mpc-1.1.0 mpc'

# On redéfinit l'éditeur de liens dynamique par défaut de GCC pour utiliser celui installé dans /tools 
# On supprime aussi /usr/include du chemin de recherche include de GCC

for file in gcc/config/{linux,i386/linux{,64}}.h
do
    su lfs -c 'cp -uv $file{,.orig}'
    su lfs -c "sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file"
    echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
done

# On définit lib comme nom de répertoire par défaut pour les bibliothèques 64 bit

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

mkdir -v build
cd build/

echo "Temps de compilation : 12 SBU"

su lfs -c '
    ../configure                                   
    --target=$LFS_TGT                              
    --prefix=/tools                                
    --with-glibc-version=2.11                      
    --with-sysroot=$LFS                            
    --with-newlib                                  
    --without-headers                              
    --with-local-prefix=/tools                     
    --with-native-system-header-dir=/tools/include 
    --disable-nls                                  
    --disable-shared                               
    --disable-multilib                             
    --disable-decimal-float                        
    --disable-threads                              
    --disable-libatomic                            
    --disable-libgomp                              
    --disable-libquadmath                          
    --disable-libssp                               
    --disable-libvtv                               
    --disable-libstdcxx                            
    --enable-languages=c,c++
    && make
    && make install'

cd $LFS/sources/
rm -rf gcc-9.2.0/
rm -rf mpfr/ gmp/ mpc/

# Linux Headers

echo "Installation de Linux API Headers ..."

su lfs -c 'tar -xf'
su lfs -c 'make mrproper'
su lfs -c 'make INSTALL_HDR_PATH=dest headers_install'
su lfs -c 'cp -rv dest/include/* /tools/include'

cd $LFS/sources/
rm -rf linux-5.2.8/
