#!/usr/bin/env bash


# LIBTOOL

tar -xf libtool-2.4.6.tar.xz
cd libtool-2.4.6/ || exit
./configure --prefix=/usr
make
make check
make install
cd ..

# GDBM

tar -xf gdbm-1.18.1.tar.gz
cd gdbm-1.18.1/ || exit
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

make
make check
make install

./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1

make 

make -j1 check
make install

cd ..

# EXPAT

tar -xf expat-2.2.7.tar.xz
cd expat-2.2.7/ || exit
sed -i 's|usr/bin/env |bin/|' run.sh.in

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.2.7

make
make check
make install
install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.7
cd ..

# INETUTILS

tar -xf inetutils-1.9.4.tar.xz
cd inetutils-1.9.4 || exit
./configure --prefix=/usr        \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers

make
make check
make install

mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin
cd ..

# PERL

tar -xf perl-5.30.0.tar.xz
cd perl-5.30.0/ || exit
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts

export BUILD_ZLIB=False
export BUILD_BZIP2=0


sh Configure -des -Dprefix=/usr                 \
                  -Dvendorprefix=/usr           \
                  -Dman1dir=/usr/share/man/man1 \
                  -Dman3dir=/usr/share/man/man3 \
                  -Dpager="/usr/bin/less -isR"  \
                  -Duseshrplib                  \
                  -Dusethreads

make
make -k test

make install
unset BUILD_ZLIB BUILD_BZIP2
cd ..

# XML PARSER

tar -xf XML-Parser-2.44.tar.gz
cd XML-Parser-2.44/ || exit
perl Makefile.PL

make
make test
make install

cd ..

# INITLOOL

tar -xf intltool-0.51.0.tar.gz
cd intltool-0.51.0/ || exit
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make check
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
cd ..

# AUTOCONF

tar -xf autoconf-2.69.tar.xz
cd autoconf-2.69/ || exit
sed '361 s/{/\\{/' -i bin/autoscan.in
./configure --prefix=/usr
make
make check
make install
cd ..

# AUTOMAKE

tar -xf automake-1.16.1.tar.xz
cd automake-1.16.1/ || exit
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1
make
make -j4
make install
cd ..

# XZ

tar -xf xz-5.2.4.tar.xz
cd xz-5.2.4/ || exit
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.4

make
make check

make install
mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
cd ..

# KMOD

tar -xf kmod-26.tar.xz
cd kmod-26/ || exit
./configure --prefix=/usr          \
            --bindir=/bin          \
            --sysconfdir=/etc      \
            --with-rootlibdir=/lib \
            --with-xz              \
            --with-zlib

make
make install


for target in depmod insmod lsmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /sbin/$target
done

ln -sfv kmod /bin/lsmod

cd ..

# GETTEXT

tar -xf gettext-0.20.1.tar.xz
cd gettext-0.20.1/ || exit
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.20.1

make
make check
make install

chmod -v 0755 /usr/lib/preloadable_libintl.so
cd ..

# ELFUTILS

tar -xf elfutils-0.177.tar.bz2
cd elfutils-0.177/ || exit
./configure --prefix=/usr
make
make check

make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig

cd ..

# LIBFFI

tar -xf libffi-3.2.1.tar.gz
cd libffi-3.2.1/ || exit
sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i include/Makefile.in

sed -e '/^includedir/ s/=.*$/=@includedir@/' \
    -e 's/^Cflags: -I${includedir}/Cflags:/' \
    -i libffi.pc.in

./configure --prefix=/usr --disable-static --with-gcc-arch=native
make
make check
make install
cd ..

# OPENSSL

tar -xf openssl-1.1.1c.tar.gz
cd openssl-1.1.1c/ || exit
sed -i '/\} data/s/ =.*$/;\n    memset(\&data, 0, sizeof(data));/' \
  crypto/rand/rand_lib.c

./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic

make
make test

sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install

mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1c
cp -vfr doc/* /usr/share/doc/openssl-1.1.1c
cd ..

# PYTHON

tar -xf Python-3.7.4.tar.xz
cd Python-3.7.4/ || exit
./configure --prefix=/usr       \
            --enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes

make

make install
chmod -v 755 /usr/lib/libpython3.7m.so
chmod -v 755 /usr/lib/libpython3.so
ln -sfv pip3.7 /usr/bin/pip3

install -v -dm755 /usr/share/doc/python-3.7.4/html 

tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.7.4/html \
    -xvf ../python-3.7.4-docs-html.tar.bz2

cd ..

# NINJA

tar -xf ninja-1.9.0
cd ninja-1.9.0/ || exit

export NINJAJOBS=4
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc

python3 configure.py --bootstrap

./ninja ninja_test
./ninja_test --gtest_filter=-SubprocessTest.SetWithLots

install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

# MESON

tar -xf meson-0.51.1.tar.gz
cd meson-0.51.1/ || exit
python3 setup.py build

python3 setup.py install --root=dest
cp -rv dest/* /
cd ..

# COREUTILS

tar -xf coreutils-8.31.tar.xz
cd coreutils-8.31/ || exit
patch -Np1 -i ../coreutils-8.31-i18n-1.patch

sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk

autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime

make
make install



mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8

mv -v /usr/bin/{head,nice,sleep,touch} /bin
cd ..

# CHECK

tar -xf check-0.12.0.tar.gz
cd check-0.12.0/ || exit
./configure --prefix=/usr

make
make check
make docdir=/usr/share/doc/check-0.12.0 install
sed -i '1 s/tools/usr/' /usr/bin/checkm
cd ..

# DIFFUTILS

tar -xf diffutils-3.7.tar.xz
cd diffutils-3.7/ || exit
./configure --prefix=/usr
make
make check
make install
cd ..

# GAWK

tar -xf gawk-5.0.1.tar.xz
cd gawk-5.0.1/ || exit
sed -i 's/extras//' Makefile.in

./configure --prefix=/usr

make

make check

make install

mkdir -v /usr/share/doc/gawk-5.0.1
cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.0.1
cd ..

# FINDUTILS

tar -xf findutils-4.6.0.tar.gz
cd findutils-4.6.0/ || exit
sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in

sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h

./configure --prefix=/usr --localstatedir=/var/lib/locate

make
make check
make install

mv -v /usr/bin/find /bin
sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb
cd ..

# GROFF

tar -xf groff-1.22.4.tar.gz
cd groff-1.22.4/ || exit
PAGE=<taille_papier> ./configure --prefix=/usr
make -j1
make install

# GRUB

tar -xf grub-2.04.tar.xz
cd grub-2.04/ || exit
./configure --prefix=/usr          \
            --sbindir=/sbin        \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror
make
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
cd ..

# LESS

tar -xf less-551.tar.gz
cd less-551/ || exit
./configure --prefix=/usr --sysconfdir=/etc

make
make install
cd ..

# GZIP
tar -xf gzip-1.10.tar.xz
cd gzip-1.10 || exit
./configure --prefix=/usr
make
make check
make install
mv -v /usr/bin/gzip /bin

# IPROUTE

tar -xf iproute2-5.2.0.tar.xz
cd iproute2-5.2.0 || exit
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8

sed -i 's/.m_ipt.o//' tc/Makefile

make
make DOCDIR=/usr/share/doc/iproute2-5.2.0 install
cd ..

# KBD

tar -xf kbd-2.2.0.tar.xz
cd kbd-2.2.0/ || exit
patch -Np1 -i ../kbd-2.2.0-backspace-1.patch

sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock

make
make check
make install
cd ..

# LIBPIPELINE

tar -xf libpipeline-1.5.1.tar.gz
cd libpipeline-1.5.1/ || exit
./configure --prefix=/usr
make
make check
make install
cd ..

# MAKE

tar -xf make-4.2.1.tar.gz
cd make-4.2.1 || exit
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/usr
make
make PERL5LIB=$PWD/tests/ check
make install
cd ..

# PATCH

tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6/ || exit
./configure --prefix=/usr
make
make check
make install
cd patch-2.7.6/ || exit

# MAN-DB

tar -xf man-db-2.8.6.1.tar.xz
cd man-db-2.8.6.1/ || exit
sed -i '/find/s@/usr@@' init/systemd/man-db.service.in

./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.8.6.1 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap
make
make check
make install
cd ..

# TAR

tar -xf tar-1.32.tar.xz
cd tar-1.32/ || exit
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr \
            --bindir=/bin
make
make check
make install

make -C doc install-html docdir=/usr/share/doc/tar-1.32
cd ..

# TEXINFO

tar -xf texinfo-6.6.tar.xz
cd texinfo-6.6/ || exit
./configure --prefix=/usr --disable-static

make
make check
make install
make TEXMF=/usr/share/texmf install-tex

pushd /usr/share/info || exit
rm -v dir
for f in *
  do install-info $f dir 2>/dev/null
done
popd || exit
cd ..

# VIM

tar -xf vim-8.1.1846.tar.gz
cd vim-8.1.1846/ || exit
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

./configure --prefix=/usr
make
make install

ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done

ln -sv ../vim/vim81/doc /usr/share/doc/vim-8.1.1846

cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1 

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
cd ..

# SYSTEMD

tar -xf systemd-241.tar.gz
cd systemd-241/ || exit
patch -Np1 -i ../systemd-241-networkd_and_rdrand_fixes-1.patch

ln -sf /tools/bin/true /usr/bin/xsltproc

for file in /tools/lib/lib{blkid,mount,uuid}.so*; do
    ln -sf $file /usr/lib/
done

tar -xf ../systemd-man-pages-241.tar.xz

sed '177,$ d' -i src/resolve/meson.build

sed -i 's/GROUP="render", //' rules/50-udev-default.rules.in

mkdir -p build
cd       build/ || exit

PKG_CONFIG_PATH="/usr/lib/pkgconfig:/tools/lib/pkgconfig" \
LANG=en_US.UTF-8                   \
CFLAGS+="-Wno-format-overflow"     \
meson --prefix=/usr                \
      --sysconfdir=/etc            \
      --localstatedir=/var         \
      -Dblkid=true                 \
      -Dbuildtype=release          \
      -Ddefault-dnssec=no          \
      -Dfirstboot=false            \
      -Dinstall-tests=false        \
      -Dkmod-path=/bin/kmod        \
      -Dldconfig=false             \
      -Dmount-path=/bin/mount      \
      -Drootprefix=                \
      -Drootlibdir=/lib            \
      -Dsplit-usr=true             \
      -Dsulogin-path=/sbin/sulogin \
      -Dsysusers=false             \
      -Dumount-path=/bin/umount    \
      -Db_lto=false                \
      -Drpmmacrosdir=no            \
      ..

LANG=en_US.UTF-8 ninja
LANG=en_US.UTF-8 ninja install

rm -f /usr/bin/xsltproc
systemd-machine-id-setup

rm -fv /usr/lib/lib{blkid,uuid,mount}.so*
rm -f /usr/lib/tmpfiles.d/systemd-nologin.conf
cd ../..

# DBUS

tar -xf dbus-1.12.16.tar.gz
cd dbus-1.12.16/ || exit
./configure --prefix=/usr                       \
            --sysconfdir=/etc                   \
            --localstatedir=/var                \
            --disable-static                    \
            --disable-doxygen-docs              \
            --disable-xml-docs                  \
            --docdir=/usr/share/doc/dbus-1.12.16 \
            --with-console-auth-dir=/run/console

make
make install

mv -v /usr/lib/libdbus-1.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libdbus-1.so) /usr/lib/libdbus-1.so

ln -sv /etc/machine-id /var/lib/dbus
cd ..

# PROCPS

tar -xf procps-ng-3.3.15.tar.xz
cd procps-ng-3.3.15/ || exit
./configure --prefix=/usr                            \
            --exec-prefix=                           \
            --libdir=/usr/lib                        \
            --docdir=/usr/share/doc/procps-ng-3.3.15 \
            --disable-static                         \
            --disable-kill                           \
            --with-systemd

make

sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
sed -i '/set tty/d' testsuite/pkill.test/pkill.exp
rm testsuite/pgrep.test/pgrep.exp

make check
makje install

mv -v /usr/lib/libprocps.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
cd ..

# UTIL-LINUX

tar -xf util-linux-2.34.tar.xz
cd util-linux-2.34/ || exit
mkdir -pv /var/lib/hwclock
rm -vf /usr/include/{blkid,libmount,uuid}
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --docdir=/usr/share/doc/util-linux-2.34 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python
make
make install
cd ..

# E2FSPROG

tar -xf e2fsprogs-1.45.3.tar.gz/
cd e2fsprogs-1.45.3 || exit
mkdir -v build
cd       build/ || exit

../configure --prefix=/usr           \
             --bindir=/bin           \
             --with-root-prefix=""   \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck
make
make check
make install
make install-libs

chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
cd ..

# NETTOYAGE

save_lib="ld-2.30.so libc-2.30.so libpthread-2.30.so libthread_db-1.0.so"

cd /lib || exit

for LIB in $save_lib; do
    objcopy --only-keep-debug $LIB $LIB.dbg 
    strip --strip-unneeded $LIB
    objcopy --add-gnu-debuglink=$LIB.dbg $LIB 
done    

save_usrlib="libquadmath.so.0.0.0 libstdc++.so.6.0.27
             libitm.so.1.0.0 libatomic.so.1.2.0" 

cd /usr/lib || exit

for LIB in $save_usrlib; do
    objcopy --only-keep-debug $LIB $LIB.dbg
    strip --strip-unneeded $LIB
    objcopy --add-gnu-debuglink=$LIB.dbg $LIB
done

unset LIB save_lib save_usrlib

exec /tools/bin/bash