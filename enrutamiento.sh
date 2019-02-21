#!/bin/bash

#Requerir sudo para ejecutar script
if [[ $UID != 0 ]]; then
    echo "Porfavor abre este script con sudo:"
    echo "sudo $0 $*"
    exit 1
fi

#Nos vamos al directorio...
cd /etc/init.d

#Parametros para la configuración
read -p "Introduce la ip de la red interna XXX.XXX.XXX.XXX/xx" SERVERIP
read -p "Introduce la interfaz que sale a internet" INTERFAZ

#Escribimos el script que se ejecutara al inicio
cat > firewall.sh <<- EOF

#Activar el enrutamiento
echo "1" > /proc/sys/net/ipv4/ip_forward

#Permitir que iptables deje pasar los paquetes y enmascararlos
iptables -A FORWARD -j ACCEPT
iptables -t nat -A POSTROUTING -s ${SERVERIP} -o ${INTERFAZ} -j ACCEPT
EOF

#Añadimos la ubicacion del script a local.rc para que se ejecute
echo "Añade la siguiente direccion al archivo antes de exit 0"
echo "/etc/init.d/firewall.sh" && sleep 5
nano /etc/rc.local

echo "Enrutamiento finalizado"
