#!/data/data/com.termux/files/usr/bin/bash
folder=debian-fs
if [ -d "$folder" ]; then
	first=1
	echo "IGNORAR DOWNLOAD"
fi
tarball="debian-rootfs.tar.xz"
if [ "$first" != 1 ];then
	if [ ! -f $tarball ]; then
		echo "BAIXANDO ROOTFS, ESTE PROCESSO PODE DEMORAR DE ACORDO COM SUA CONEXÃO À INTERNET."
		case `dpkg --print-architecture` in
		aarch64)
			archurl="arm64" ;;
		arm)
			archurl="armhf" ;;
		amd64)
			archurl="amd64" ;;
		x86_64)
			archurl="amd64" ;;	
		i*86)
			archurl="i386" ;;
		x86)
			archurl="i386" ;;
		*)
			echo "unknown architecture"; exit 1 ;;
		esac
		wget "https://raw.githubusercontent.com/EXALAB/AnLinux-Resources/master/Rootfs/Debian/${archurl}/debian-rootfs-${archurl}.tar.xz" -O $tarball
	fi
	cur=`pwd`
	mkdir -p "$folder"
	cd "$folder"
	echo "DESCOMPRIMINDO ROOTFS, AGUARDE."
	proot --link2symlink tar -xJf ${cur}/${tarball}||:
	cd "$cur"
fi
mkdir -p debian-binds
bin=start-debian.sh
echo "CRIANDO SCRIPT .SH"
cat > $bin <<- EOM
#!/bin/bash
cd \$(dirname \$0)
if [ `id -u` = 0 ];then
    pulseaudio --start --system
else
    pulseaudio --start
fi
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder"
if [ -n "\$(ls -A debian-binds)" ]; then
    for f in debian-binds/* ;do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b debian-fs/root:/dev/shm"
## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
## uncomment the following line to mount /sdcard directly to / 
#command+=" -b /sdcard"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

echo "CONFIGURANDO PULSEAUDIO."

pkg install pulseaudio -y

if grep -q "anonymous" ~/../usr/etc/pulse/default.pa;then
    echo "MODULO EXISTENTE"
else
    echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >> ~/../usr/etc/pulse/default.pa
fi

echo "exit-idle-time = -1" >> ~/../usr/etc/pulse/daemon.conf
echo "MODIFICAR O TEMPO DE AUTO-DESATIVACAO DE PULSEAUDIO PARA INFINITO"
echo "autospawn = no" >> ~/../usr/etc/pulse/client.conf
echo "DESATIVAR AUTO-INICIO DE PULSEAUDIO"
echo "EXPORTAR PULSE_SERVER=127.0.0.1" >> debian-fs/etc/profile
echo "CONFIGURANDO SERVIDOR PULSEAUDIO 127.0.0.1"

echo "fixing shebang of $bin"
termux-fix-shebang $bin
echo "making $bin executable"
chmod +x $bin
echo "REMOVER IMAGEM PARA SALVAR ESPACO"
rm $tarball
echo "INICIE DEBIAN UTILIZANDO O COMANDO ./${bin}."
