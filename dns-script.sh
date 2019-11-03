#!/bin/bash
#Autor:Martín Jesús Mañas Rivas
#
# Simple script to generate a basic bind configuration for home/lab use
#


#Requerir sudo para ejecutar script
if [[ $UID != 0 ]]; then
    echo "Porfavor abre este script con sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Local config - adjust as required
read -p "Introduce la ip de tu servidor: " OWNIP
#OWNIP=192.168.111.3

read -p "Introduce la ip de tu red: " NETWORK
#NETWORK=192.168.111.0

read -p "Introduce la mascara de tu red -> /8 /16 /24... " NETMASK
#NETMASK=/24

read -p "Introduce la direccion del servidor DNS (tu servidor u otro): " DNS1
#DNS1=192.168.111.1
DNS2=

#Comprobar que no haya campos vacios
if [ -z $OWNIP ]  || [ -z $NETWORK ] || [ -z $NETMASK ] || [ -z $DNS1 ];then
    echo "Uno de los valores esta vacio"
    exit 1
fi

# Advanced - should not be changed
read -p "Introduce el nombre de tu dominio -> ejemplo.com: " DOMAIN
#DOMAIN=lab.local

#Set the hostname
HOSTNAME=$(hostname)


# Internal - must not be changed
CONFDIR=/etc/bind

# Let's go - make sure we're in the right path
if [[ ! -d "${CONFDIR}" ]]
  then
        echo "ERROR: configuration path ${CONFDIR} does not exist, exiting"
        exit 1
  else
        echo "Configuration path ${CONFDIR}"
        cd $CONFDIR || exit 1
  fi

# Stop bind
echo "Stopping bind9 daemon..."
service bind9 stop

# Remove the root zone servers, we don't want to query these directly
[[ ! -f db.root.original ]] && mv db.root db.root.original
cat > db.root <<- EOF
\$TTL   30d
@       IN      SOA     localhost. root.localhost. (
                          1     ; Serial
                        30d     ; Refresh
                         1d     ; Retry
                        30d     ; Expire
                        30d     ; Negative Cache TTL
                        )
;
@       IN      NS      localhost.
EOF
echo "Created db.root"

# Set bind options and upstream DNS servers
[[ ! -f named.conf.options.original ]] && mv named.conf.options named.conf.options.original
cat > named.conf.options <<- EOF
options {
        directory "/var/cache/bind";
        auth-nxdomain no;
        listen-on { any; };
        listen-on-v6 { any; };
        allow-recursion { 127.0.0.1; ${NETWORK}${NETMASK}; };
EOF
printf "\tforwarders { ${DNS1}" >> named.conf.options
[[ -n "${DNS2}" ]] && printf "; ${DNS2}" >> named.conf.options
printf "; };\n};\n" >> named.conf.options
echo "Created named.conf.options"

# Configure the local domain
[[ ! -f named.conf.local.original ]] && mv named.conf.local named.conf.local.original
REVADDR=$(for FIELD in 3 2 1; do printf "$(echo ${NETWORK} | cut -d '.' -f $FIELD)."; done)
cat > named.conf.local <<- EOF
zone "${DOMAIN}" {
        type master;
        notify no;
        file "${CONFDIR}/db.${DOMAIN}";
};
zone "${REVADDR}in-addr.arpa" {
        type master;
        notify no;
        file "${CONFDIR}/db.${REVADDR}in-addr.arpa";
};
include "${CONFDIR}/zones.rfc1918";
EOF
echo "Created named.conf.local"

# Populate the forward zone
SERIAL="$(date '+%Y%m%d')01"
NET="$(echo ${NETWORK} | cut -d '.' -f 1-3)"
cat > db.${DOMAIN} <<- EOF
\$ORIGIN ${DOMAIN}.
\$TTL   1d
${DOMAIN}.       IN      SOA     ${HOSTNAME}. root.${DOMAIN}. (
                        ${SERIAL}       ; Serial
                        1d              ; Refresh
                        2h              ; Retry
                        1w              ; Expire
                        2d              ; Negative Cache TTL
                        )
${DOMAIN}.        IN      NS      ${HOSTNAME}.${DOMAIN}.
${DOMAIN}.        IN      A       ${OWNIP}
${HOSTNAME}       IN      A       ${OWNIP}
${DOMAIN}.        IN      MX      10      mail.${DOMAIN}.
mail              IN      A       ${OWNIP}
ftp               IN      CNAME   ${HOSTNAME}
www               IN      CNAME   ${HOSTNAME}
smtp              IN      CNAME   ${HOSTNAME}
pop3              IN      CNAME   ${HOSTNAME}
imap              IN      CNAME   ${HOSTNAME}
EOF
echo "Populated forward zone file db.${DOMAIN} for ${DOMAIN}"

# Populate the reverse zone
OWNH="$(echo ${OWNIP} | cut -d '.' -f 4)"
cat > db.${REVADDR}in-addr.arpa <<- EOF
\$ORIGIN ${REVADDR}in-addr.arpa.
\$TTL   1d
${REVADDR}in-addr.arpa.       IN      SOA     ${HOSTNAME}. root.${DOMAIN}. (
                        ${SERIAL}       ; Serial
                        1d              ; Refresh
                        2h              ; Retry
                        1w              ; Expire
                        2d              ; Negative Cache TTL
                        )
${REVADDR}in-addr.arpa.         IN      NS      ${HOSTNAME}.${DOMAIN}.
${OWNH} IN      PTR     ${HOSTNAME}.${DOMAIN}.
${OWNH} IN      PTR     mail.${DOMAIN}.
${OWNH} IN      PTR     ftp.${DOMAIN}.
${OWNH} IN      PTR     www.${DOMAIN}.
${OWNH} IN      PTR     smtp.${DOMAIN}.
${OWNH} IN      PTR     pop3.${DOMAIN}.
${OWNH} IN      PTR     imap.${DOMAIN}.
EOF
echo "Populated reverse zone file db.${REVADDR}in-addr.arpa for ${NET}"

# Enable local DNS server
[[ ! -f /etc/resolv.conf.original ]] && mv /etc/resolv.conf /etc/resolv.conf.original
cat > /etc/resolv.conf <<- EOF
domain ${DOMAIN}
search ${DOMAIN}
nameserver ${OWNIP}
nameserver 8.8.8.8
EOF
echo "Enabled local DNS server in /etc/resolv.conf"

# Start bind
echo "Starting bind9 daemon..."
service bind9 start

# Done
echo "Done."
