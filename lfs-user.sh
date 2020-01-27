#!/bin/bash

# TODO ajouter pause entre chaque compilation
# ------------ COMPILATION ------------



# On assure la propreté de la chaîne d'outil

cd "$LFS/sources" || exit

# BINUTILS (27s)
echo "Compilation de BINUTILS ... 
(le temps renvoyé à la fin est une unité caractéristique appelé SBU qui servira d'indicateur pour le temps de compilation des paquets suivants)"
tar -xf binutils-2.32.tar.xz
cd binutils-2.32/ || exit

mkdir -v build/
cd build/ || exit

../configure \
--prefix=/tools \
--with-sysroot="$LFS" \
--with-lib-path=/tools/lib \
--target="$LFS_TGT" \
--disable-nls \
--disable-werror \
&& make \

case $(uname -m) in
  x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac

make install

cd "$LFS/sources/" || exit 
rm -rf binutils-2.32/

read -r -p "Appuyer sur ENTER pour continuer" enter

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
cd build/ || exit

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

read -r -p "Appuyer sur ENTER pour continuer" enter

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

read -r -p "Appuyer sur ENTER pour continuer" enter

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

# if [  "$(readelf -l a.out | grep ': /tools')" != "[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]" ];
# then
#     echo "Installation invalide !";
#     exit 1;
# fi

# echo "Installation validée"

rm -v dummy.c a.out

cd "$LFS/sources/" || exit
rm -rf glibc-2.30/

read -r -p "Appuyer sur ENTER pour continuer" enter

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

read -r -p "Appuyer sur ENTER pour continuer" enter

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

read -r -p "Appuyer sur ENTER pour continuer" enter

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
# if [ "$(readelf -l a.out | grep ': /tools')" != "[Requesting program interpreter: /tools/lib64/ld-linux-x86-64.so.2]" ];
# then
#     echo "Installation invalide !";
#     exit 1;
# fi
#echo "Installation valide"

rm -v dummy.c a.out
cd "$LFS/sources/" || exit
rm -rf gcc-9.2.0/

read -r -p "Appuyer sur ENTER pour continuer" enter

# TCL

echo "Compilation de TCL ..."

tar -xf tcl8.6.9-src.tar.gz
cd tcl8.6.9-src/ || exit

echo "Temps de compilation : 0.9 SBU"

cd unix/ || exit
./configure \
--prefix=/tools \
&& make \
&& TZ=UTC make test \
&& make install

chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh

cd "$LFS/sources/" || exit
rm -rf tcl8.6.9-src/

read -r -p "Appuyer sur ENTER pour continuer" enter

# EXPECT

echo "Compilation de EXPECT ..."
tar -xf expect5.45.4.tar.gz
cd expect5.45.4/ || exit

echo "Temps de compilation : 0.1 SBU"

cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure

./configure           \
--prefix=/tools       \
--with-tcl=/tools/lib \
--with-tclinclude=/tools/include \
&& make \
&& make test \
&& make SCRIPTS="" install

cd "$LFS/sources/" || exit
rm -rf expect5.45.4/

read -r -p "Appuyer sur ENTER pour continuer" enter

# DEJA GNU

echo "Compilation de DejaGNU ..."
tar -xf dejagnu-1.6.2.tar.gz
cd dejagnu-1.6.2/ || exit

echo "Temps de compilaition : < 0.1 SBU"

./configure \
--prefix=/tools \
&& make install \
&& make check

cd "$LFS/sources/" || exit
rm -rf dejagnu-1.6.2/

read -r -p "Appuyer sur ENTER pour continuer" enter

# M4

echo "Compilation de M4 ..."
tar -xf m4-1.4.18.tar.xz
cd m4-1.4.18/ || exit

echo "Temps de compilation  : 0.2 SBU"

sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install


cd "$LFS/sources/" || exit
rm -rf m4-1.4.18/
read -r -p "Appuyer sur ENTER pour continuer" enter

# NCURSES

echo "Compilation de NCURSES ..."
tar -xf ncurses-6.1.tar.gz
cd ncurses-6.1/ || exit

echo "Temps de compilation : 0.6 SBU"
sed -i s/mawk// configure

./configure \
--prefix=/tools \
--with-shared   \
--without-debug \
--without-ada   \
--enable-widec  \
--enable-overwrite \
&& make \
&& make install

ln -s libncursesw.so /tools/lib/libncurses.so

cd "$LFS/sources/" || exit
rm -rf ncurses-6.1/
read -r -p "Appuyer sur ENTER pour continuer" enter

# BASH

echo "Compilation de BASH ..."
tar -xf bash-5.0.tar.gz
cd bash-5.0/ || exit

echo "Temps de compilation : 0.2 SBU"

./configure \
--prefix=/tools \
--without-bash-malloc \
&& make \
&& make tests \
&& make install

ln -sv bash /tools/bin/sh

cd "$LFS/sources/" || exit
rm -rf bash-5.0/
read -r -p "Appuyer sur ENTER pour continuer" enter

# BISON

echo "Compilation de BISON ..."
tar -xf bison-3.4.1.tar.xz
cd bison-3.4.1/ || exit

echo "Temps de compilation : 0.3 SBU"

 ./configure \
 --prefix=/tools \
 && make \
 && make check \
 && make install

cd "$LFS/sources/" || exit
rm -rf bison-3.4.1/
read -r -p "Appuyer sur ENTER pour continuer" enter

# BZIP2

echo "Compilation de BZIP2 ..."
tar -xf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8/ || exit

echo "Temps de compilation : < 0.1 SBU"

make \
&& make PREFIX=/tools install

cd "$LFS/sources/" || exit
rm -rf bzip2-1.0.8/
read -r -p "Appuyer sur ENTER pour continuer" enter

# COREUTILS

echo "Compilation de COREUTILS ..."
tar -xf coreutils-8.31.tar.xz
cd coreutils-8.31/ || exit

echo "Temps de compilation : 0.8 SBU"

./configure \
--prefix=/tools \
--enable-install-program=hostname \
&& make \
&& make RUN_EXPENSIVE_TESTS=yes check \
&& make install

cd "$LFS/sources/" || exit
rm -rf coreutils-8.31/
read -r -p "Appuyer sur ENTER pour continuer" enter

# DIFFUTILS

echo "Compilation de DIFFUTILS ..."
tar -xf diffutils-3.7.tar.xz
cd diffutils-3.7/ || exit

echo "Temps de compilation : 0.2 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check  \
&& make install

cd "$LFS/sources/" || exit
rm -rf diffutils-3.7/
read -r -p "Appuyer sur ENTER pour continuer" enter

# FILE

echo "Compilation de FILE ..."
tar -xf file-5.37.tar.gz
cd file-5.37/ || exit

echo "Temps de compilation : 0.1 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf file-5.37/
read -r -p "Appuyer sur ENTER pour continuer" enter

# FINDUTILS

echo "Compilation de FINDUTILS ..."
tar -xf  findutils-4.6.0.tar.gz
cd findutils-4.6.0.tar.gz || exit

echo "Temps de compilation : 0.3 SBU"

sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf findutilds-4.6.0.tar.gz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# GAWK

echo "Compilation de GAWK ..."
tar -xf gawk-5.0.1.tar.xz
cd gawk-5.0.1.tar.xz/ || exit

echo "Temps de compilation : 0.3 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf gawk-5.0.1.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# GETTEXT

echo "Compilation de GETTEXT ..."
tar -xf gettext-0.20.1.tar.xz
cd gettext-0.20.1.tar.xz/ || exit

echo "Temps de compilation : 1.8 SBU"

./configure \
--disable-shared \
&& make

cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin


cd "$LFS/sources/" || exit
rm -rf gettext-0.20.1.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# GREP

echo "Compilation de GETTEXT ..."
tar -xf grep-3.3.tar.xz
cd grep-3.3.tar.xz/ || exit

echo "Temps de compilation : 0.2 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf grep-3.3.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# GZIP

echo "Compilation de GZIP ..."
tar -xf gzip-1.10.tar.xz
cd gzip-1.10.tar.xz/ || exit

echo "Temps de compilation : 0.1 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf gzip-1.10.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# MAKE

echo "Compilation de MAKE ..."
tar -xf make-4.2.1.tar.gz
cd make-4.2.1.tar.gz/ || exit

echo "Temps de compilation : 0.1 SBU"

sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure \
--prefix=/tools \
--without-guile \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf make-4.2.1.tar.gz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# PATCH

echo "Compilation de PATCH ..."
tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6.tar.xz/ || exit

echo "Temps de compilation : 0.2 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf patch-2.7.6.tar.gz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# PERL

echo "Compilation de PERL ..."
tar -xf perl-5.30.0.tar.xz
cd perl-5.30.0.tar.xz/ || exit

echo "Temps de compilation : 1.6 SBU"

sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth
make
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.30.0
cp -Rv lib/* /tools/lib/perl5/5.30.0

cd "$LFS/sources/" || exit
rm -rf perl-5.30.0.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# PYTHON

echo "Compilation de PYTHON ..."
tar -xf Python-3.7.4.tar.xz
cd Python-3.7.4.tar.xz/ || exit

echo "Temps de compilation : 1.4 SBU"

sed -i '/def add_multiarch_paths/a \        return' setup.py
./configure \
--prefix=/tools \
--without-ensurepip \
&& make \
&& make install

cd "$LFS/sources/" || exit
rm -rf Python-3.7.4.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# SED

echo "Compilation de SED ..."
tar -xf sed-4.7.tar.xz
cd sed-4.7.tar.xz/ || exit

echo "Temps de compilation : 0.2 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf sed-4.7.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# TAR

echo "Compilation de TAR ..."
tar -xf tar-1.32.tar.xz
cd tar-1.32.tar.xz/ || exit

echo "Temps de compilation : 0.3 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf tar-1.32.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# TEXINFO

echo "Compilation de TEXINFO ..."
tar -xf texinfo-6.6.tar.xz
cd texinfo-6.6.tar.xz/ || exit

echo "Temps de compilation : 0.2 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf texinfo-6.6.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# UTIL-LINUX

echo "Compilation de UTIL-LINUX ..."
tar -xf util-linux-2.34.tar.xz
cd util-linux-2.34.tar.xz/ || exit

echo "Temps de compilation : 1 SBU"

./configure \
--prefix=/tools \
--without-python \
--disable-makeinstall-chown \
--without-systemdsystemunitdir \
--without-ncurses \
PKG_CONFIG="" \
&& make \
&& make install

cd "$LFS/sources/" || exit
rm -rf util-linux-2.34.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# XZ

echo "Compilation de XZ ..."
tar -xf xz-5.2.4.tar.xz
cd xz-5.2.4.tar.xz/ || exit

echo "Temps de compilation : 0.2 SBU"

./configure \
--prefix=/tools \
&& make \
&& make check \
&& make install

cd "$LFS/sources/" || exit
rm -rf xz-5.2.4.tar.xz/
read -r -p "Appuyer sur ENTER pour continuer" enter

# Liébration de l'espace

echo "Nettoyage ..."

strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*

rm -rf /tools/{,share}/{info,man,doc}

find /tools/{lib,libexec} -name \*.la -delete

chown -R root:root "$LFS/tools"