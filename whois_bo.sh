#!/bin/bash

DOMINIO="$1"
LISTA="subdominios_nic.txt"

# =====================================
# Validaciones iniciales
# =====================================

if [ -z "$DOMINIO" ]; then
    echo "Uso: $0 dominio"
    echo "Ejemplo: $0 minedu.gob.bo"
    exit 1
fi

if [ ! -f "$LISTA" ]; then
    echo "[-] No existe el archivo: $LISTA"
    exit 1
fi

echo "[+] Analizando dominio: $DOMINIO"

# =====================================
# Verificar que sea .bo
# =====================================

if [[ "$DOMINIO" != *.bo ]]; then
    echo "[-] El dominio no pertenece a NIC Bolivia (.bo)"
    exit 0
fi

echo "[+] Dominio .BO detectado"

# =====================================
# Buscar la categoría más específica
# =====================================

CATEGORIA=""
LONGITUD=0

while read -r SUB
do
    # Ignorar líneas vacías
    [ -z "$SUB" ] && continue

    if [[ "$DOMINIO" == *"$SUB" ]]; then

        ACTUAL=${#SUB}

        if [ "$ACTUAL" -gt "$LONGITUD" ]; then
            CATEGORIA="$SUB"
            LONGITUD=$ACTUAL
        fi

    fi

done < "$LISTA"

# =====================================
# Validar categoría encontrada
# =====================================

if [ -z "$CATEGORIA" ]; then
    echo "[-] No se encontró una categoría válida de NIC Bolivia."
    exit 1
fi

echo "[+] Categoría NIC: $CATEGORIA"

# =====================================
# Obtener el dominio registrable
# =====================================

BASE="${DOMINIO%$CATEGORIA}"
BASE="${BASE%.}"

DOMINIO_NIC="${BASE##*.}"

echo "[+] Dominio registrable: $DOMINIO_NIC"

# =====================================
# Consultar WHOIS de NIC Bolivia
# =====================================

echo
echo "[+] Consultando NIC Bolivia..."

RESPUESTA=$(curl --silent --compressed \
    -A "Mozilla/5.0" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "dominio=${DOMINIO_NIC}&subdominio=${CATEGORIA}&enviar=" \
    "https://nic.bo/whois.php")

if [ -z "$RESPUESTA" ]; then
    echo "[-] No se recibió respuesta del servidor."
    exit 1
fi

echo "[+] Respuesta recibida."

# =====================================
# Extraer URL de revisión
# =====================================

URL_RELATIVA=$(echo "$RESPUESTA" | grep -o 'revisar_contacto.php?[^"]*')

if [ -z "$URL_RELATIVA" ]; then
    echo "[-] No se pudo obtener la URL del WHOIS."
    exit 1
fi

URL_COMPLETA="https://nic.bo/$URL_RELATIVA"

echo "[+] URL encontrada:"
echo "    $URL_COMPLETA"

# =====================================
# Descargar ficha WHOIS
# =====================================

echo
echo "[+] Descargando ficha WHOIS..."

HTML_TMP="plantilla.html"

curl --silent --compressed \
    -L \
    -A "Mozilla/5.0" \
    "$URL_COMPLETA" \
    -o "$HTML_TMP"

if [ ! -s "$HTML_TMP" ]; then
    echo "[-] No se pudo descargar la ficha WHOIS."
    exit 1
fi

echo "[+] HTML descargado correctamente."

# =====================================
# Procesar HTML
# =====================================

DOMINIO_COMPLETO="${DOMINIO_NIC}${CATEGORIA}"

./datos_whois.sh "$HTML_TMP" "$DOMINIO_COMPLETO"

if [ $? -ne 0 ]; then
    echo "[-] Error al procesar el WHOIS."
    exit 1
fi

# Eliminar HTML temporal
rm -f "$HTML_TMP"
