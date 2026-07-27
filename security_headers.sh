#!/bin/bash

# ==========================================================
# security_headers.sh
#
# Analiza las cabeceras HTTP de todos los hosts válidos
# obtenidos previamente mediante dnsx.
#
# Uso:
# ./security_headers.sh dominio dns_dominio.txt
#
# Ejemplo:
# ./security_headers.sh minedu.gob.bo \
# resultados/minedu.gob.bo/dns_minedu.gob.bo.txt
#
# ==========================================================

DOMINIO="$1"
DNS_FILE="$2"

# ==========================================================
# Validaciones
# ==========================================================

if [ -z "$DOMINIO" ] || [ -z "$DNS_FILE" ]; then

    echo "Uso:"
    echo "$0 dominio dns_dominio.txt"
    exit 1

fi

if [ ! -f "$DNS_FILE" ]; then

    echo "[-] No existe:"
    echo "$DNS_FILE"
    exit 1

fi

# ==========================================================
# Directorios
# ==========================================================

DIR="resultados/$DOMINIO"

mkdir -p "$DIR"

SALIDA="$DIR/security_headers_$DOMINIO.txt"

# ==========================================================
# Temporales únicos por ejecución
# ==========================================================

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

TMP_HOSTS="$TMPDIR_WORK/hosts.txt"

# ==========================================================
# Obtener únicamente los hosts
# ==========================================================

awk '
NR>9 && NF>0{
    print $1
}
' "$DNS_FILE" | sort -u > "$TMP_HOSTS"

TOTAL=$(wc -l < "$TMP_HOSTS")

if [ "$TOTAL" -eq 0 ]; then

    echo "No existen hosts."
    exit 1

fi

echo
echo "[+] Hosts encontrados: $TOTAL"
echo

# ==========================================================
# Crear reporte
# ==========================================================

cat > "$SALIDA" <<EOF
==============================================================================================================================
                                         ANALISIS DE CABECERAS HTTP
==============================================================================================================================

Dominio: $DOMINIO

HOST                                     HSTS  CSP  XFO XCTO  RP  PP  SCORE
--------------------------------------------------------------------------------------------------------------

EOF

# ==========================================================
# Contadores
# ==========================================================

TOTAL_HSTS=0
TOTAL_CSP=0
TOTAL_XFO=0
TOTAL_XCTO=0
TOTAL_RP=0
TOTAL_PP=0

ANALIZADOS=0

echo "[+] Analizando cabeceras..."
echo

# ==========================================================
# Procesar cada host
# ==========================================================

while read -r HOST
do

    echo "    -> $HOST"

    HEADERS=$(curl \
        -k \
        -L \
        -I \
        --connect-timeout 5 \
        --max-time 10 \
        -A "Mozilla/5.0" \
        "https://$HOST" \
        2>/dev/null)

    if [ -z "$HEADERS" ]; then
        continue
    fi

    SCORE=0

    HSTS="NO"
    CSP="NO"
    XFO="NO"
    XCTO="NO"
    RP="NO"
    PP="NO"
    # ==========================================================
    # Strict-Transport-Security
    # ==========================================================

    if echo "$HEADERS" | grep -iq "^Strict-Transport-Security:"; then

        HSTS="SI"
        SCORE=$((SCORE+2))
        TOTAL_HSTS=$((TOTAL_HSTS+1))

    fi


    # ==========================================================
    # Content-Security-Policy
    # ==========================================================

    if echo "$HEADERS" | grep -iq "^Content-Security-Policy:"; then

        CSP="SI"
        SCORE=$((SCORE+2))
        TOTAL_CSP=$((TOTAL_CSP+1))

    fi


    # ==========================================================
    # X-Frame-Options
    # ==========================================================

    if echo "$HEADERS" | grep -iq "^X-Frame-Options:"; then

        XFO="SI"
        SCORE=$((SCORE+1))
        TOTAL_XFO=$((TOTAL_XFO+1))

    fi


    # ==========================================================
    # X-Content-Type-Options
    # ==========================================================

    if echo "$HEADERS" | grep -iq "^X-Content-Type-Options:"; then

        XCTO="SI"
        SCORE=$((SCORE+1))
        TOTAL_XCTO=$((TOTAL_XCTO+1))

    fi


    # ==========================================================
    # Referrer-Policy
    # ==========================================================

    if echo "$HEADERS" | grep -iq "^Referrer-Policy:"; then

        RP="SI"
        SCORE=$((SCORE+1))
        TOTAL_RP=$((TOTAL_RP+1))

    fi


    # ==========================================================
    # Permissions-Policy
    # ==========================================================

    if echo "$HEADERS" | grep -iq "^Permissions-Policy:"; then

        PP="SI"
        SCORE=$((SCORE+1))
        TOTAL_PP=$((TOTAL_PP+1))

    fi


    printf "%-40s %-5s %-4s %-4s %-5s %-4s %-4s %d/8\n" \
        "$HOST" \
        "$HSTS" \
        "$CSP" \
        "$XFO" \
        "$XCTO" \
        "$RP" \
        "$PP" \
        "$SCORE" \
        >> "$SALIDA"

    ANALIZADOS=$((ANALIZADOS+1))

done < "$TMP_HOSTS"



# ==========================================================
# Resumen
# ==========================================================

cat >> "$SALIDA" <<EOF

==============================================================================================================================
RESUMEN
==============================================================================================================================

Hosts analizados                  : $ANALIZADOS

Strict-Transport-Security         : $TOTAL_HSTS
Content-Security-Policy           : $TOTAL_CSP
X-Frame-Options                   : $TOTAL_XFO
X-Content-Type-Options            : $TOTAL_XCTO
Referrer-Policy                   : $TOTAL_RP
Permissions-Policy                : $TOTAL_PP

==============================================================================================================================

Leyenda

HSTS  = Strict-Transport-Security
CSP   = Content-Security-Policy
XFO   = X-Frame-Options
XCTO  = X-Content-Type-Options
RP    = Referrer-Policy
PP    = Permissions-Policy

Puntaje máximo: 8

==============================================================================================================================

EOF


echo
echo "[+] Reporte generado:"
echo "    $SALIDA"

echo
echo "[+] Hosts analizados : $ANALIZADOS"
