#!/bin/bash

#Requerir sudo para ejecutar script
if [[ $UID != 0 ]]; then
    echo "Porfavor abre este script con sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Internal - must not be changed
CONFDIR=/etc/dhcp

# Let's go - make sure we're in the right path
if [[ ! -d "${CONFDIR}" ]]
then
        echo "ERROR: configuration path ${CONFDIR} does not exist, exiting"
        exit 1
else
        echo "Configuration path ${CONFDIR}"
        cd $CONFDIR || exit 1
fi


PS3='Elige una opción: '
options=("Configurar DHCP" "Agregar Direccion Fija" "Salir")
select opt in "${options[@]}"
do
	case $opt in
		"Configurar DHCP")
		echo "Configurando DHCP..."
		echo "Ponga el nombre de su tarjeta de red en interfaces='eth0|enp3s0'"
		sleep 5 && sudo nano /etc/default/isc-dhcp-server
		
		read -p "Introduce direccion del servidor: " IPSERVER
        read -p "Introduce direccion de red: " IPRED
        read -p "Introduce la mascara de red(255.XXX.XXX.XX): " NETMASK
        read -p "Introduce el rango de ip (xxx.xxx.xxx.xxx xxx.xxx.xxx.xxx: " IPRANGE
        read -p "Enter domain name" DOMAIN
        
        #Comprobar que no haya campos vacios
        if [ -z $IPSERVER ]  || [ -z $IPRED ] || [ -z $NETMASK] || [ -z $IPRANGE ] || [ -z $DOMAIN ] ;then
            echo "Uno de los valores esta vacio"
            exit 1
        fi
        
 		cat > dhcpd.conf <<- EOF
 		# Configuración DHCP #
		option domain-name-servers ${IPSERVER}, 8.8.8.8;
        default-lease-time 86400;
        max-lease-time 7200;
        authoritative; #Establece este servidor como prioritario
        
        subnet ${IPRED} netmask ${NETMASK} {
        range ${IPRANGE};
        option routers ${IPSERVER};
        option domain-name "${DOMAIN}";
		}
		
		EOF
		echo "Reiniciando DHCP..."
		sudo service isc-dhcp-server restart
		;;
		"Agregar Direccion Fija")
		echo "Agregando una direccion fija..."
		read -p "Introduce el nombre del cliente: " CLIENTNAME
		read -p "Introduce la mac del cliente A2:G3:1W:12:AC:R1" MAC
		read -p "Introduce la ip fija que tendra: " IP
		
		#Comprobar que no haya campos vacios
        if [ -z $CLIENTNAME ]  || [ -z $MAC ] || [ -z $IP ] ;then
            echo "Uno de los valores esta vacio"
            exit 1
        fi
		
        cat >> dhcpd.conf <<- EOF
 		host ${CLIENTNAME} {
            hardware ethernet ${MAC};
            fixed-address ${IP};
 		}
		
		EOF
		echo "Reiniciando DHCP..."
		sudo service isc-dhcp-server restart
		;;
		"Salir")
		echo "Saliendo del programa" && sleep 2 && break 
        ;;
		*) echo "Opcion Invalida"
	esac
done
