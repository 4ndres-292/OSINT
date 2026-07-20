#!/bin/bash

DOMINIO="$1"
DNS_FILE="$2"

# =====================================
# Validaciones
# =====================================

if [ -z "$DOMINIO" ] || [ -z "$DNS_FILE" ]; then
    echo "Uso:"
    echo "$0 dominio dns.txt"
    exit 1
fi

if [ ! -f "$DNS_FILE" ]; then
    echo "No existe:"
    echo "$DNS_FILE"
    exit 1
fi

DIR="resultados/$DOMINIO"
mkdir -p "$DIR"

SALIDA="$DIR/certificados_$DOMINIO.txt"

TMP="/tmp/certificados_hosts.txt"

# =====================================
# Obtener únicamente los hosts válidos
# =====================================

awk '
NR>5 && NF>0{
    print $1
}
' "$DNS_FILE" | sort -u > "$TMP"

TOTAL=$(wc -l < "$TMP")

echo "[+] Analizando certificados SSL..."
echo "[+] Hosts encontrados: $TOTAL"

cat > "$SALIDA" <<EOF
=========================================================================
                    CERTIFICADOS SSL - $DOMINIO
=========================================================================

HOST                                   EMISOR                    VENCE                DIAS
---------------------------------------------------------------------------------------------------------------

EOF

# =====================================
# Consultar certificados
# =====================================

while read HOST
do

CERT=$(echo | openssl s_client \
-connect ${HOST}:443 \
-servername ${HOST} 2>/dev/null)

if [ -z "$CERT" ]; then
    continue
fi

EMISOR=$(echo "$CERT" |
openssl x509 -noout -issuer 2>/dev/null |
sed 's/issuer=//' |
sed 's/.*O *= *//' |
cut -d',' -f1)

VENCE=$(echo "$CERT" |
openssl x509 -noout -enddate 2>/dev/null |
cut -d= -f2)

if [ -z "$VENCE" ]; then
    continue
fi

FECHA=$(date -d "$VENCE" +%Y-%m-%d 2>/dev/null)

DIAS=$(( ($(date -d "$FECHA" +%s) - $(date +%s)) / 86400 ))

printf "%-38s %-25s %-20s %5s\n" \
"$HOST" \
"$EMISOR" \
"$FECHA" \
"$DIAS" \
>> "$SALIDA"

done < "$TMP"

rm -f "$TMP"

echo
echo "[+] Reporte generado:"
echo "$SALIDA"
