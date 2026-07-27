#!/bin/bash

# ==========================================================
# whois_bo.sh - Consulta WHOIS
#
# Detecta automaticamente si el dominio pertenece a NIC
# Bolivia (.bo) y usa el procedimiento correspondiente.
#
# NIC Bolivia: whois_bo.sh → datos_whois.sh
# Estandar:    whois + parser whitelist
#
# Salida: resultados/[dominio]/whois_[dominio].txt
# ==========================================================

DOMINIO="$1"
LISTA="subdominios_nic.txt"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# =====================================
# Validaciones iniciales
# =====================================

if [ -z "$DOMINIO" ]; then
    echo "Uso: $0 dominio"
    echo "Ejemplo: $0 minedu.gob.bo"
    exit 1
fi

echo "[+] Analizando dominio: $DOMINIO"

# =====================================
# Detectar si pertenece a NIC Bolivia
# =====================================

ES_NIC_BO=false

if [[ "$DOMINIO" == *.bo ]]; then

    if [ -f "$LISTA" ]; then

        CATEGORIA=""
        LONGITUD=0

        while read -r SUB; do
            [ -z "$SUB" ] && continue
            if [[ "$DOMINIO" == *"$SUB" ]]; then
                ACTUAL=${#SUB}
                if [ "$ACTUAL" -gt "$LONGITUD" ]; then
                    CATEGORIA="$SUB"
                    LONGITUD=$ACTUAL
                fi
            fi
        done < "$LISTA"

        if [ -n "$CATEGORIA" ]; then
            ES_NIC_BO=true
        fi

    fi

fi

# =====================================
# Temporales únicos por ejecución
# =====================================

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

# =====================================
# FLUJO NIC BOLIVIA
# =====================================

if [ "$ES_NIC_BO" = true ]; then

    echo "[+] Dominio .BO detectado"
    echo "[+] Categoria NIC: $CATEGORIA"

    BASE="${DOMINIO%$CATEGORIA}"
    BASE="${BASE%.}"
    DOMINIO_NIC="${BASE##*.}"

    echo "[+] Dominio registrable: $DOMINIO_NIC"

    echo
    echo "[+] Consultando NIC Bolivia..."

    RESPUESTA=$(curl --silent --compressed \
        -A "Mozilla/5.0" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "dominio=${DOMINIO_NIC}&subdominio=${CATEGORIA}&enviar=" \
        "https://nic.bo/whois.php")

    if [ -z "$RESPUESTA" ]; then
        echo "[-] No se recibio respuesta del servidor."
        exit 1
    fi

    echo "[+] Respuesta recibida."

    URL_RELATIVA=$(echo "$RESPUESTA" | grep -o 'revisar_contacto.php?[^"]*')

    if [ -z "$URL_RELATIVA" ]; then
        echo "[-] No se pudo obtener la URL del WHOIS."
        exit 1
    fi

    URL_COMPLETA="https://nic.bo/$URL_RELATIVA"

    echo "[+] URL encontrada:"
    echo "    $URL_COMPLETA"

    echo
    echo "[+] Descargando ficha WHOIS..."

    HTML_TMP="$TMPDIR_WORK/whois_plantilla.html"

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

    DOMINIO_COMPLETO="${DOMINIO_NIC}${CATEGORIA}"

    "$SCRIPT_DIR/datos_whois.sh" "$HTML_TMP" "$DOMINIO_COMPLETO"

    if [ $? -ne 0 ]; then
        echo "[-] Error al procesar el WHOIS."
        exit 1
    fi

    exit 0

fi

# =====================================
# FLUJO WHOIS ESTANDAR
# =====================================

echo "[+] Dominio no pertenece a NIC Bolivia"
echo "[+] Usando whois estandar..."

DIR="resultados/$DOMINIO"
mkdir -p "$DIR"

SALIDA="$DIR/whois_${DOMINIO}.txt"

TMP_WHOIS="$TMPDIR_WORK/whois_raw.txt"

whois "$DOMINIO" > "$TMP_WHOIS" 2>/dev/null

if [ ! -s "$TMP_WHOIS" ]; then
    echo "[-] No se recibio respuesta del servidor WHOIS."
    rm -f "$TMP_WHOIS"
    exit 1
fi

echo "[+] Procesando respuesta WHOIS..."

# =====================================
# Parser whitelist - extraer campos relevantes
# =====================================

awk -v dom="$DOMINIO" '
BEGIN {
    print "=========================================="
    print "           WHOIS - " dom
    print "=========================================="
    print ""
    print "Dominio consultado : " dom
    print ""
    dominio_printed=0
    registrante_printed=0
    admin_printed=0
    tech_printed=0
    dns_printed=0
    seen_domain=0
    seen_registrar=0
    seen_creation=0
    seen_expiry=0
    seen_updated=0
    seen_dnssec=0
    seen_regid=0
    seen_ns=0
    ns_count=0
}

/^$/ { next }
/^%/ { next }
/^#/ { next }
/Terms of Use/ { next }
/NOTICE/ { next }
/Copyright/ { next }
/Last update of whois database/ { next }
/>>> Last update/ { next }
/Data protected/ { next }
/Privacy Protect/ { next }
/This whois service/ { next }
/For more information/ { next }
/By submitting/ { next }
/The Registrar/ { next }
/understands/ { next }
/agrees/ { next }
/Domain available/ { next }
/No match for/ {
    if (!dominio_printed) {
        print "=========================================="
        print "Informacion del Dominio"
        print "=========================================="
        print ""
        dominio_printed=1
    }
    print "Estado: NO ENCONTRADO"
    next }
/Domain Name:/ {
    if (!seen_domain) {
        if (!dominio_printed) {
            print "=========================================="
            print "Informacion del Dominio"
            print "=========================================="
            print ""
            dominio_printed=1
        }
        val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%-25s : %s\n", "Domain Name", val
        seen_domain=1
    }
    next }
/Registrar:/ {
    if (!seen_registrar) {
        val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%-25s : %s\n", "Registrar", val
        seen_registrar=1
    }
    next }
/Registry Expiry Date:|Registry Expiration Date:|Expiration Date:|Registrar Registration Expiration Date:/ {
    if (!seen_expiry) {
        val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%-25s : %s\n", "Expiry Date", val
        seen_expiry=1
    }
    next }
/Creation Date:/ {
    if (!seen_creation) {
        val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%-25s : %s\n", "Creation Date", val
        seen_creation=1
    }
    next }
/Updated Date:/ {
    if (!seen_updated) {
        val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%-25s : %s\n", "Updated Date", val
        seen_updated=1
    }
    next }
/DNSSEC:/ {
    if (!seen_dnssec) {
        val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%-25s : %s\n", "DNSSEC", val
        seen_dnssec=1
    }
    next }
/Registry Domain ID:/ {
    if (!seen_regid) {
        val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
        printf "%-25s : %s\n", "Registry Domain ID", val
        seen_regid=1
    }
    next }

# Registrante
/Registrant Name:/ {
    if (!registrante_printed) {
        print ""
        print "=========================================="
        print "Registrante"
        print "=========================================="
        print ""
        registrante_printed=1
    }
    val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
    printf "%-25s : %s\n", "Name", val
    next }
/Registrant Organization:/ {
    if (!registrante_printed) {
        print ""
        print "=========================================="
        print "Registrante"
        print "=========================================="
        print ""
        registrante_printed=1
    }
    val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
    printf "%-25s : %s\n", "Organization", val
    next }
/Registrant Country:/ {
    if (!registrante_printed) {
        print ""
        print "=========================================="
        print "Registrante"
        print "=========================================="
        print ""
        registrante_printed=1
    }
    val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
    printf "%-25s : %s\n", "Country", val
    next }
/Registrant Email:/ {
    if (!registrante_printed) {
        print ""
        print "=========================================="
        print "Registrante"
        print "=========================================="
        print ""
        registrante_printed=1
    }
    val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
    printf "%-25s : %s\n", "Email", val
    next }

# Contacto Administrativo
/Admin Email:/ {
    if (!admin_printed) {
        print ""
        print "=========================================="
        print "Contacto Administrativo"
        print "=========================================="
        print ""
        admin_printed=1
    }
    val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
    printf "%-25s : %s\n", "Email", val
    next }
/Administrative Contact:/ {
    if (!admin_printed) {
        print ""
        print "=========================================="
        print "Contacto Administrativo"
        print "=========================================="
        print ""
        admin_printed=1
    }
    next }

# Contacto Tecnico
/Tech Email:/ {
    if (!tech_printed) {
        print ""
        print "=========================================="
        print "Contacto Tecnico"
        print "=========================================="
        print ""
        tech_printed=1
    }
    val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
    printf "%-25s : %s\n", "Email", val
    next }
/Technical Contact:/ {
    if (!tech_printed) {
        print ""
        print "=========================================="
        print "Contacto Tecnico"
        print "=========================================="
        print ""
        tech_printed=1
    }
    next }

# Name Servers (deduplicados)
/Name Server:/ {
    val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
    ns=tolower(val)
    duplicado=0
    for (i=1; i<=ns_count; i++) {
        if (ns_list[i] == ns) { duplicado=1; break }
    }
    if (!duplicado) {
        ns_count++
        ns_list[ns_count]=ns
        if (!dns_printed) {
            print ""
            print "=========================================="
            print "Servidores DNS"
            print "=========================================="
            print ""
            dns_printed=1
        }
        printf "%-25s : %s\n", "Name Server", ns
    }
    next }

END {
    print ""
    print "=========================================="
}
' "$TMP_WHOIS" > "$SALIDA"

echo
echo "[+] Reporte generado:"
echo "    $SALIDA"
