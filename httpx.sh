#!/bin/bash

DOMINIO="$1"
DNS_FILE="$2"

HTTPX="$HOME/go/bin/httpx"

# ==========================================
# Validaciones
# ==========================================

if [ -z "$DOMINIO" ] || [ -z "$DNS_FILE" ]; then
    echo "Uso:"
    echo "$0 dominio dns_archivo.txt"
    exit 1
fi

if [ ! -f "$DNS_FILE" ]; then
    echo "No existe el archivo:"
    echo "$DNS_FILE"
    exit 1
fi

DIR="resultados/$DOMINIO"

mkdir -p "$DIR"

SALIDA="$DIR/httpx_$DOMINIO.txt"

TMP="/tmp/httpx_hosts.txt"
RAW="/tmp/httpx_raw.txt"

# ==========================================
# Obtener únicamente hosts válidos
# ==========================================

awk '
NR>6 && ($2=="A" || $2=="AAAA" || $2=="CNAME") {
    print $1
}
' "$DNS_FILE" | sort -u > "$TMP"

TOTAL=$(wc -l < "$TMP")

echo "[+] Hosts encontrados: $TOTAL"
echo
echo "[+] Ejecutando httpx..."
echo

# ==========================================
# Ejecutar httpx
# ==========================================

"$HTTPX" \
-l "$TMP" \
-title \
-tech-detect \
-status-code \
-content-length \
-follow-host-redirects \
-silent | \
sed -r 's/\x1B\[[0-9;]*[mK]//g' \
> "$RAW"

if [ ! -s "$RAW" ]; then
    echo "[-] No hubo resultados."
    rm -f "$TMP"
    exit 1
fi

# ==========================================
# Crear reporte
# ==========================================

cat > "$SALIDA" <<EOF
=========================================================================================================================
                                   TECNOLOGIAS WEB - $DOMINIO
=========================================================================================================================

SUBDOMINIO                               HTTP     TAMAÑO     TITULO                                   TECNOLOGIAS
-------------------------------------------------------------------------------------------------------------------------

EOF

while read -r linea
do

    HOST=$(echo "$linea" | cut -d' ' -f1)

    STATUS=$(echo "$linea" | grep -o '\[[0-9]\{3\}\]' | head -1 | tr -d '[]')

    SIZE=$(echo "$linea" | grep -o '\[[0-9]\+\]' | sed -n '2p' | tr -d '[]')

    TITULO=$(echo "$linea" | grep -o '\[[^]]*\]' | sed -n '3p' | tr -d '[]')

    TECNO=$(echo "$linea" | grep -o '\[[^]]*\]' | sed -n '4p' | tr -d '[]')

    printf "%-40s %-8s %-10s %-40s %s\n" \
        "$HOST" \
        "$STATUS" \
        "$SIZE" \
        "$TITULO" \
        "$TECNO" \
        >> "$SALIDA"

done < "$RAW"

rm -f "$TMP"
rm -f "$RAW"

echo
echo "[+] Reporte generado:"
echo "$SALIDA"
