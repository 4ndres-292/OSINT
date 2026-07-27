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

SALIDA="$DIR/wayback_$DOMINIO.txt"

# =====================================
# Extraer subdominios válidos
# =====================================

TMP="$TMPDIR_WORK/hosts.txt"

awk '
NR>9 && NF>0 {
    print $1
}
' "$DNS_FILE" | sort -u > "$TMP"

TOTAL=$(wc -l < "$TMP")

echo
echo "[+] Subdominios a analizar: $TOTAL"

echo
echo "[+] Consultando Wayback Machine..."

# =====================================
# Crear reporte
# =====================================

cat > "$SALIDA" <<EOF

============================================================
              WAYBACK MACHINE - $DOMINIO
============================================================


SUBDOMINIO                     URL HISTORICA
------------------------------------------------------------

EOF

# =====================================
# Consulta por cada host
# =====================================

while read -r HOST
do
    echo "[+] Analizando: $HOST"

    HOST_JSON="$TMPDIR_WORK/wayback_host.json"

    curl -s --max-time 30 \
    "https://web.archive.org/cdx/search/cdx?url=$HOST/*&output=json&fl=original,statuscode,mimetype&filter=statuscode:200&collapse=urlkey" \
    > "$HOST_JSON"

    if [ -s "$HOST_JSON" ]; then
        python3 <<PYEOF >> "$SALIDA"
import json, re

host="$HOST"

STATIC_EXTS=re.compile(r'\.(jpg|jpeg|png|gif|svg|webp|ico|bmp|tiff|css|js|mjs|woff|woff2|ttf|eot|otf|mp3|mp4|avi|mov|wmv|flv|webm|ogg|wav)(\?|$)', re.I)
STATIC_TYPES={'image/jpeg','image/png','image/gif','image/svg+xml','image/webp','image/x-icon','image/bmp','image/tiff','text/css','application/javascript','text/javascript','application/x-javascript','font/woff','font/woff2','font/ttf','font/eot','application/font-woff','application/font-woff2','audio/mpeg','video/mp4'}
ADMIN_RE=re.compile(r'/(admin|login|panel|dashboard|cpanel|wp-admin|wp-login|phpmyadmin|manager|console|backoffice)', re.I)
API_RE=re.compile(r'/(api|swagger|graphql|openapi|rest|soap|webservice|wsdl|_api)|\?api|\.api\.', re.I)
CONFIG_RE=re.compile(r'\.well-known/|assetlinks\.json|ai-plugin\.json|robots\.txt|sitemap\.xml|security\.txt|humans\.txt|crossdomain\.xml|clientaccesspolicy\.xml', re.I)
DOC_RE=re.compile(r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|rtf|csv|txt)$', re.I)
BACKUP_RE=re.compile(r'\.(zip|rar|7z|bak|sql|tar\.gz|db|dump|old|orig|backup|save)$', re.I)

def is_interesting(url, mimetype):
    path=url.split('?',1)[0]
    if mimetype in STATIC_TYPES: return False
    if STATIC_EXTS.search(path): return False
    if ADMIN_RE.search(path): return True
    if API_RE.search(path): return True
    if CONFIG_RE.search(path): return True
    if DOC_RE.search(path): return True
    if BACKUP_RE.search(path): return True
    lp=path.lower()
    if lp.endswith('.html') or lp.endswith('.htm') or lp.endswith('/'): return True
    if mimetype=='text/html': return True
    return False

try:
    with open("$HOST_JSON") as f:
        datos=json.load(f)
    for item in datos[1:]:
        url=item[0]; codigo=item[1]; tipo=item[2]
        if is_interesting(url, tipo):
            print(f"{host:<35} {codigo:<8} {tipo:<30} {url}")
except:
    pass
PYEOF
    fi

done < "$TMP"

# =====================================
# Limpieza
# =====================================

sort -u "$SALIDA" -o "$SALIDA"

echo
echo "[+] Reporte generado:"
echo "$SALIDA"
echo "[+] Tamano: $(wc -c < "$SALIDA") bytes, $(wc -l < "$SALIDA") lineas"
