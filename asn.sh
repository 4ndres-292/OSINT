#!/bin/bash

DOMINIO="$1"
DNSFILE="$2"

# =====================================
# Validaciones
# =====================================

if [ -z "$DOMINIO" ] || [ -z "$DNSFILE" ]; then

    echo "Uso:"
    echo "$0 dominio archivo_dns"

    echo
    echo "Ejemplo:"
    echo "$0 minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt"

    exit 1
fi

if [ ! -f "$DNSFILE" ]; then

    echo "[-] No existe el archivo:"
    echo "$DNSFILE"

    exit 1
fi

# =====================================
# Directorio de salida
# =====================================

DIR="resultados/$DOMINIO"

mkdir -p "$DIR"

SALIDA="$DIR/asn_$DOMINIO.txt"

TMP_IP="/tmp/ip_unicas.txt"

# =====================================
# Extraer IPs únicas
# =====================================

grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' "$DNSFILE" \
| sort -u > "$TMP_IP"

if [ ! -s "$TMP_IP" ]; then

    echo "[-] No se encontraron IPs."

    exit 1

fi

# =====================================
# Crear reporte
# =====================================

cat > "$SALIDA" <<EOF
============================================================
                ANALISIS ASN - $DOMINIO
============================================================

IPs únicas encontradas:

EOF

cat "$TMP_IP" >> "$SALIDA"

cat >> "$SALIDA" <<EOF


============================================================
DETALLE POR ASN
============================================================

EOF

TMP_ASN="/tmp/asn_vistos.txt"

> "$TMP_ASN"

# =====================================
# Analizar cada IP
# =====================================

while read -r IP
do

    echo "[+] Analizando $IP ..."

    INFO=$(curl -s "https://ipinfo.io/$IP/json")

    ASN=$(echo "$INFO" | jq -r '.org' | awk '{print $1}')

    ORG=$(echo "$INFO" | jq -r '.org' | sed 's/^AS[0-9]* //')

    PAIS=$(echo "$INFO" | jq -r '.country')

    CIUDAD=$(echo "$INFO" | jq -r '.city')

    HOSTNAME=$(echo "$INFO" | jq -r '.hostname')

    printf "\n--------------------------------------------------\n" >> "$SALIDA"
    printf "IP            : %s\n" "$IP" >> "$SALIDA"
    printf "ASN           : %s\n" "$ASN" >> "$SALIDA"
    printf "Organización  : %s\n" "$ORG" >> "$SALIDA"
    printf "País          : %s\n" "$PAIS" >> "$SALIDA"
    printf "Ciudad        : %s\n" "$CIUDAD" >> "$SALIDA"
    printf "Hostname      : %s\n" "$HOSTNAME" >> "$SALIDA"

    if grep -qx "$ASN" "$TMP_ASN"; then
        continue
    fi

    echo "$ASN" >> "$TMP_ASN"

    echo "[+] Consultando WHOIS de $ASN..."

    WHOIS=$(whois "$ASN")

    OWNER=$(echo "$WHOIS" | grep -iE 'owner|org-name|descr' | head -1 | cut -d: -f2- | xargs)

    ADDRESS=$(echo "$WHOIS" | grep -i '^address' | head -1 | cut -d: -f2- | xargs)

    PHONE=$(echo "$WHOIS" | grep -i '^phone' | head -1 | cut -d: -f2- | xargs)

    EMAIL=$(echo "$WHOIS" | grep -iE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+' | head -1)

    printf "Propietario   : %s\n" "$OWNER" >> "$SALIDA"
    printf "Dirección     : %s\n" "$ADDRESS" >> "$SALIDA"
    printf "Teléfono      : %s\n" "$PHONE" >> "$SALIDA"
    printf "Contacto      : %s\n" "$EMAIL" >> "$SALIDA"

done < "$TMP_IP"

rm -f "$TMP_IP"
rm -f "$TMP_ASN"

echo
echo "[+] Reporte generado:"
echo "$SALIDA"
