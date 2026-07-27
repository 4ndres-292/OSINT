#!/bin/bash

DOMINIO="$1"
DNS_FILE="$2"

# =====================================
# Validaciones
# =====================================

if [ -z "$DOMINIO" ] || [ -z "$DNS_FILE" ]; then
    echo "Uso:"
    echo "$0 dominio archivo_dns"
    echo
    echo "Ejemplo:"
    echo "$0 minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt"
    exit 1
fi

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo:"
    echo "$DNS_FILE"
    exit 1
fi

# =====================================
# Temporales únicos por ejecución
# =====================================

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# =====================================
# Carpetas
# =====================================

DIR="resultados/$DOMINIO"
mkdir -p "$DIR"

SALIDA="$DIR/katana_$DOMINIO.txt"
SALIDA_FILTRADA="$DIR/katana_filtrado_$DOMINIO.txt"

# =====================================
# Extraer hosts válidos
# =====================================

TMP="$TMPDIR_WORK/hosts.txt"

awk '
NR>9 && NF>0 {
    print $1
}
' "$DNS_FILE" | sort -u > "$TMP"

TOTAL=$(wc -l < "$TMP")

echo
echo "[+] Hosts para crawling: $TOTAL"

# =====================================
# Crear URLs
# =====================================

URLS_FILE="$TMPDIR_WORK/urls.txt"
sed 's#^#https://#' "$TMP" > "$URLS_FILE"

echo
echo "[+] Ejecutando Katana..."
echo

# =====================================
# Ejecutar Katana
# =====================================

RAW="$TMPDIR_WORK/raw.txt"

katana \
-list "$URLS_FILE" \
-c 10 \
-depth 3 \
-js-crawl \
-silent \
-automatic-form-fill \
-o "$RAW"

if [ ! -s "$RAW" ]; then
    echo "[-] No se encontraron URLs"
    exit 1
fi

# =====================================
# Reporte final
# =====================================

cat > "$SALIDA" <<EOF

============================================================
              KATANA WEB CRAWLING - $DOMINIO
============================================================


URLS DESCUBIERTAS

------------------------------------------------------------

EOF

cat "$RAW" | sort -u >> "$SALIDA"

TOTAL_URL=$(wc -l < "$RAW")

echo
echo "[+] URLs encontradas: $TOTAL_URL"

echo
echo "[+] Reporte generado:"
echo "$SALIDA"

# =====================================
# Filtrar URLs interesantes
# =====================================

echo
echo "[+] Filtrando URLs relevantes..."

grep -Ei \
'admin|login|api|swagger|auth|user|panel|dashboard|config|backup|upload|download|token|xml|json' \
"$RAW" \
| grep -Ev '\.(jpg|jpeg|png|gif|svg|css|woff|woff2|ttf|ico|mp4|mp3)$' \
| grep -Ev '[A-Za-z0-9+/]{40,}={0,2}' \
| sort -u \
> "$SALIDA_FILTRADA"

TOTAL_FILTRADO=$(wc -l < "$SALIDA_FILTRADA")

echo "[+] URLs filtradas: $TOTAL_FILTRADO"
echo "[+] Reporte filtrado:"
echo "$SALIDA_FILTRADA"
