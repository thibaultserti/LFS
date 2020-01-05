#!/bin/bash

# TODO ajouter pause entre chaque compilation
# ------------ COMPILATION ------------

# On assure la propreté de la chaîne d'outil

case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac

cd "$LFS/sources" || exit

# BINUTILS (27s)
echo "Compilation de BINUTILS ... 
(le temps renvoyé à la fin est une unité caractéristique appelé SBU qui servira d'indicateur pour le temps de compilation des paquets suivants)"
tar -xf binutils-2.32.tar.xz
cd binutils-2.32/ || exit

mkdir -v build
cd build/ || exit

time { ../configure \
        --prefix=/tools \
        --with-sysroot="$LFS" \
        --with-lib-path=/tools/lib \
        --target="$LFS_TGT" \
        --disable-nls \
        --disable-werror \
        && make \
        && make install;}

cd "$LFS/sources/" || exit 
rm -rf binutils-2.32

read -pr "Appuyer sur ENTER pour continuer"

# GCC

echo "Compilation de GCC ..."
tar -xf gcc-9.2.0.tar.xz
cd gcc-9.2.0/ || exit

tar -xf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc

# On redéfinit l'éditeur de liens dynamique par défaut de GCC pour utiliser celui installé dans /tools 
# On supprime aussi /usr/include du chemin de recherche include de GCC

for file in gcc/config/{linux,i386/linux{,64}}.h
do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
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
cd build/ ||

echo "Temps de compilation : 12 SBU"

../configure \
--target="$LFS_TGT" \
--prefix=/tools \
--with-glibc-version=2.11 \
--with-sysroot="$LFS" \
--with-newlib \
--without-headers \
--with-local-prefix=/tools \
--with-native-system-header-dir=/tools/include \
--disable-nls \
--disable-shared \
--disable-multilib \
--disable-decimal-float \
--disable-threads \
--disable-libatomic \
--disable-libgomp \
--disable-libquadmath \
--disable-libssp \
--disable-libvtv \
--disable-libstdcxx \
--enable-languages=c,c++ \
&& make \
&& make install

cd "$LFS/sources/" || exit
rm -rf gcc-9.2.0/
rm -rf mpfr/ gmp/ mpc/

read -pr "Appuyer sur ENTER pour continuer"

# LINUX HEADERS

echo "Installation de Linux API Headers ..."
echo "Temps de compilation : 0.1 SBU"

tar -xf linux-5.2.8.tar.xz
cd linux-5.2.8/ || exit
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include

cd "$LFS/sources/" || exit
rm -rf linux-5.2.8/

read -pr "Appuyer sur ENTER pour continuer"

# GLIBC

echo "Compilation de GLIBC..."

tar -xf glibc-2.30.tar.xz
cd glibc-2.30/ || exit
mkdir -v build
cd build/ || exit

echo "Temps de compilation : 4.8 SBU"

../configure \
--prefix=/tools \
--host="$LFS_TGT" \
--build="$(../scripts/config.guess)" \
--enable-kernel=3.2 \
--with-headers=/tools/include \
&& make \
&& make install

echo "Test de l'installation ..."

echo 'int main(){}' > dummy.c
"$LFS_TGT-gcc" dummy.c

if [  "$(readelf -l a.out | grep ': /tools')" != "[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]" ];
then
    echo "Installation invalide !";
    exit 1;
fi

echo "Installation validée"

rm -v dummy.c a.out

cd "$LFS/sources/" || exit
rm -rf glibc-2.30/

read -pr "Appuyer sur ENTER pour continuer"

# LIBSTDC++

echo "Compilation de LIBSTDC++ ..."
tar -xf gcc-9.2.0.tar.xz
cd gcc-9.2.0 || exit

mkdir -v build
cd build/ || exit

echo "Temps de compilation : 0.5 SBU"


../libstdc++-v3/configure \
--host="$LFS_TGT" \
--prefix=/tools \
--disable-multilib \
--disable-nls \
--disable-libstdcxx-threads \
--disable-libstdcxx-pch \
--with-gxx-include-dir="/tools/$LFS_TGT/include/c++/9.2.0" \
&& make \
&& make install


cd "$LFS/sources/" || exit
rm -rf gcc-9.2.0/

read -pr "Appuyer sur ENTER pour continuer"

# Binutils 2

echo "Compilation de BINUTILS ..."
tar -xf binutils-2.32.tar.xz
cd binutils-2.32/ || exit

mkdir -v build
cd build/ || exit

echo "Temps de compilation : 1.1 SBU"

CC="$LFS_TGT-gcc"
CXX="$LFS_TGT-g++"
AR="$LFS_TGT-ar"
RANLIB="$LFS_TGT-ranlib"

../configure \
--prefix=/tools \
--disable-nls \
--disable-werror \
--with-lib-path=/tools/lib \
--with-sysroot \
&& make \
&& make install

make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin

cd "$LFS/sources/" || exit
rm -rf binutils-2.32/

read -pr "Appuyer sur ENTER pour continuer"

# GCC (2nd pass)

echo "Compilation de GCC ..."
tar -xf gcc-9.2.0.tar.xz
cd gcc-9.2.0/ || exit

cat gcc/limitx.h gcc/glimits.h gcc/limity.h > "$(dirname "$("$LFS_TGT"-gcc -print-libgcc-file-name)")"/include-fixed/limits.h

for file in gcc/config/{linux,i386/linux{,64}}.h
do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
    #undef STANDARD_STARTFILE_PREFIX_1
    #undef STANDARD_STARTFILE_PREFIX_2
    #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
    #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
done

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

tar -xf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc

mkdir -v build
cd build/ || exit

echo "Temps de compilation : 15 SBU"

CC="$LFS_TGT-gcc'"
CXX="$LFS_TGT-g++"
AR="$LFS_TGT-ar"
RANLIB="$LFS_TGT-ranlib"

../configure \
--prefix=/tools \
--with-local-prefix=/tools \
--with-native-system-header-dir=/tools/include \
--enable-languages=c,c++ \
--disable-libstdcxx-pch \
--disable-multilib \
--disable-bootstrap \
--disable-libgomp \
&& make \
&& make install

su lfs -c "ln -sv gcc /tools/bin/cc"

echo 'int main(){}' > dummy.c
cc dummy.c
if [ "$(readelf -l a.out | grep ': /tools')" != "[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]" ];
then
    echo "Installation invalide !";
    exit 1;
fi

rm -v dummy.c a.out
cd "$LFS/sources/" || exit
rm -rf gcc-9.2.0/