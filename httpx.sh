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

# Temporales únicos por ejecución
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

TMP="$TMPDIR_WORK/hosts.txt"
RAW="$TMPDIR_WORK/raw.txt"

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
    exit 1
fi

# ==========================================
# Crear reporte — formato bracket para parsing
# ==========================================

cat > "$SALIDA" <<EOF
========================================================================================================================
                                   TECNOLOGIAS WEB - $DOMINIO
========================================================================================================================

EOF

# Output bracket format for report parsing
while read -r linea
do
    echo "$linea" >> "$SALIDA"
done < "$RAW"

TOTAL_URL=$(wc -l < "$RAW")

echo
echo "[+] Hosts procesados: $TOTAL_URL"
echo
echo "[+] Reporte generado:"
echo "$SALIDA"
