#!/bin/bash

cd "$LFS/sources"/ || exit

# API HEADERS LINUX
tar -xf linux-5.2.8.tar.xz/
cd linux-5.2.8/ || exit
make headers
find usr/include -name '.*' -delete
rm usr/include/Makefile
cp -rv usr/include/* /usr/include
cd ..

# MAN
tar -xf man-pages-5.02.tar.xz
cd man-pages-5.02/ || exit
make install
cd ..

# GLIBC
tar -xf glibc-2.30.tar.xz
cd glibc-2.30 || exit
patch -Np1 -i ../glibc-2.30-fhs-1.patch
sed -i '/asm.socket.h/a# include <linux/sockios.h>' \
   sysdeps/unix/sysv/linux/bits/socket.h
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    ;;
esac
mkdir -v build/
cd build/ || exit
CC="gcc -ffile-prefix-map=/tools=/usr" \
../configure --prefix=/usr                          \
             --disable-werror                       \
             --enable-kernel=3.2                    \
             --enable-stack-protector=strong        \
             --with-headers=/usr/include            \
             libc_cv_slibdir=/lib

make
case $(uname -m) in
  i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
  x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
esac

make check

touch /etc/ld.so.conf

sed "/test-installation/s@$(PERL)@echo not running@" -i ../Makefile

make install

cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd

install -v -Dm644 ../nscd/nscd.tmpfiles /usr/lib/tmpfiles.d/nscd.conf
install -v -Dm644 ../nscd/nscd.service /lib/systemd/system/nscd.service


mkdir -pv /usr/lib/locale
localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS

make localedata/install-locales

cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

tar -xf ../../tzdata2019b.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward pacificnew systemv; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO

tzselect

ln -sfv /usr/share/zoneinfo/Europe/Paris /etc/localtime

cat > /etc/ld.so.conf << "EOF"
# Début de /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

cat >> /etc/ld.so.conf << "EOF"
# Ajout d'un répertoire include
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
cd ..

# Ajustement de la chaîne d'outils
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/"$(uname -m)"-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld "/tools/$(uname -m)-pc-linux-gnu/bin/ld"

gcc -dumpspecs | sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    "$(dirname "$(gcc --print-libgcc-file-name)")"/specs

# ZLIB

tar -xf zlib-1.2.11.tar.xz
cd zlib-1.2.11/ || exit
./configure --prefix=/usr
make
make check
make install
mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/"$(readlink /usr/lib/libz.so)" /usr/lib/libz.so
cd ..

# FILE

tar -xf file-5.37.tar.gz
cd file-5.37/ || exit
./configure --prefix=/usr
make
make check
make install
cd ..

# READLINE

tar -xf readline-8.0.tar.gz
cd readline-8.0/ || exit
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/readline-8.0
make SHLIB_LIBS="-L/tools/lib -lncursesw"

make SHLIB_LIBS="-L/tools/lib -lncursesw" install

mv -v /usr/lib/lib{readline,history}.so.* /lib
chmod -v u+w /lib/lib{readline,history}.so.*
ln -sfv ../../lib/"$(readlink /usr/lib/libreadline.so)" /usr/lib/libreadline.so
ln -sfv ../../lib/"$(readlink /usr/lib/libhistory.so )" /usr/lib/libhistory.so
cd ..

# M4

tar -xf m4-1.4.18.tar.xz
cd m4-1.4.18/ || exit
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

./configure --prefix=/usr
make
make check
make install
cd ..

# BC

tar -xf bc-2.1.3.tar.gz
cd bc-2.1.3/ || exit
PREFIX=/usr CC=gcc CFLAGS="-std=c99" ./configure.sh -G -O3
make
make test
make install
cd ..

# BINUTILS

tar -xf binutils-2.32.tar.xz
cd binutils-2.32 || exit
expect -c "spawn ls"
sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in

mkdir -v build
cd       build/ || exit

../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib

make tooldir=/usr

make -k check

make tooldir=/usr install

cd ..

# GMP

tar -xf gmp-6.1.2.tar.xz
cd gmp-6.1.2/ || exit
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.1.2

make
make html

make check 2>&1 | tee gmp-check-log

awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log

make install
make install-html
cd ..

# MPFR

tar -xf mpfr-4.0.2.tar.xz
cd mpfr-4.0.2/ || exit
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.0.2

make
make html
make check
make install
make install-html
cd ..

# MPC

tar -xf mpc-1.1.0.tar.gz
cd mpc-1.1.0/ || exit
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.1.0

make
make html
make check
make install 
make install-html

cd ..

# SHADOW

tar -xf shadow-4.7.tar.xz
cd shadow-4.7/ || exit
sed -i "s/groups$(EXEEXT) //" src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs


sed -i 's/1000/999/' etc/useradd

./configure --sysconfdir=/etc --with-group-name-max-length=32

make
make install

mv -v /usr/bin/passwd /bin

pwconv
grpconv

passwd root
cd ..

# GCC

tar -xf gcc-9.2.0.tar.xz
cd gcc-9.2.0/ || exit
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

mkdir -v build
cd       build/ || exit

SED=sed                               \
../configure --prefix=/usr            \
             --enable-languages=c,c++ \
             --disable-multilib       \
             --disable-bootstrap      \
             --with-system-zlib
make

ulimit -s 32768
chown -Rv nobody . 
su nobody -s /bin/bash -c "PATH=$PATH make -k check"
../contrib/test_summary

make install
rm -rf /usr/lib/gcc/"$(gcc -dumpmachine)"/9.2.0/include-fixed/bits/

chown -v -R root:root \
    /usr/lib/gcc/*linux-gnu/9.2.0/include{,-fixed}

ln -sv ../usr/bin/cpp /lib
ln -sv gcc /usr/bin/cc

install -v -dm755 /usr/lib/bfd-plugins
ln -sfv ../../libexec/gcc/"$(gcc -dumpmachine)"/9.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
cd ../..

# BZIP

tar -xf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8/ || exit
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i "s@\(ln -s -f \)$(PREFIX)/bin/@\1@" Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install

cp -v bzip2-shared /bin/bzip2
cp -av libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat
cd ..

# PKG-CONFIG

tar -xf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2/ || exit
./configure --prefix=/usr              \
            --with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2

make
make check
make install
cd ..

# NCURSES

tar -xf ncurses-6.1.tar.gz
cd ncurses-6.1/ || exit
sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --enable-pc-files       \
            --enable-widec

make
make install

mv -v /usr/lib/libncursesw.so.6* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so

for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done

rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so

mkdir -v       /usr/share/doc/ncurses-6.1
cp -v -R doc/* /usr/share/doc/ncurses-6.1
cd ..

# ATTR

tar -xf attr-2.4.48.tar.gz
cd attr-2.4.48/ || exit
./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.4.48

make
make check
make install
mv -v /usr/lib/libattr.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
cd ..

# ACL

tar -xf acl-2.2.53.tar.gz
cd acl-2.2.53/ || exit
./configure --prefix=/usr         \
            --disable-static      \
            --libexecdir=/usr/lib \
            --docdir=/usr/share/doc/acl-2.2.53
make
make install
mv -v /usr/lib/libacl.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
cd ..

# LIBCAP

tar -xf libcap-2.27.tar.xz
cd libcap-2.27.tar.xz/ || exit
sed -i '/install.*STALIBNAME/d' libcap/Makefile
make
make RAISE_SETFCAP=no lib=lib prefix=/usr install
chmod -v 755 /usr/lib/libcap.so.2.27
mv -v /usr/lib/libcap.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
cd ..

# SED

tar -xf sed-4.7.tar.xz
cd sed-4.7 || exit
sed -i 's/usr/tools/'                 build-aux/help2man
sed -i 's/testsuite.panic-tests.sh//' Makefile.in

./configure --prefix=/usr --bindir=/bin

make
make html
make check

make install
install -d -m755           /usr/share/doc/sed-4.7
install -m644 doc/sed.html /usr/share/doc/sed-4.7
cd ..

# PSMISC

tar -xf psmisc-23.2.tar.xz
cd psmisc-23.2.tar.xz || exit
./configure --prefix=/usr
make
make install
mv -v /usr/bin/fuser   /bin
mv -v /usr/bin/killall /bin
cd ..

# IANA-ETC
tar -xf iana-etc-2.30.tar.bz2
cd iana-etc-2.30/ || exit
make
make install
cd ..

# BISON

tar -xf bison-3.4.1.tar.xz
cd bison-3.4.1/ || exit
sed -i '6855 s/mv/cp/' Makefile.in
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.4.1
make -j1

make install

cd ..

# FLEX
tar -xf flex-2.6.4.tar.gz/
cd flex-2.6.4/ || exit
sed -i "/math.h/a #include <malloc.h>" src/flexdef.h


HELP2MAN=/tools/bin/true \
./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4

make
make check
make install
ln -s flex /usr/bin/lex
cd ..

# GREP

tar -xf grep-3.3.tar.xz
cd grep-3.3/ || exit
./configure --prefix=/usr --bindir=/bin
make
make -k check
make install
cd ..

# BASH

tar -xf bash-5.0.tar.gz
cd bash-5.0/ || exit
./configure --prefix=/usr                    \
            --docdir=/usr/share/doc/bash-5.0 \
            --without-bash-malloc            \
            --with-installed-readline

make

chown -Rv nobody .

su nobody -s /bin/bash -c "PATH=$PATH HOME=/home make tests"

make install
mv -vf /usr/bin/bash /bin
cd ..
exec /bin/bash --login +h
