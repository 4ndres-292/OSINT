#!/bin/bash

# ==========================================================
# osint.sh - Orquestador de reconocimiento OSINT
#
# Ejecuta una pipeline completa de reconocimiento sobre un
# dominio objetivo, generando reportes en resultados/$dominio/
#
# Uso: ./osint.sh dominio.gob.bo
# ==========================================================


DOMINIO="$1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"


# =====================================
# Validaciones
# =====================================

if [ -z "$DOMINIO" ]; then
    echo "Uso: $0 dominio"
    echo "Ejemplo: $0 minedu.gob.bo"
    exit 1
fi


# =====================================
# Preparar entorno
# =====================================

DIR="$SCRIPT_DIR/resultados/$DOMINIO"
LOG_ERRORES="$DIR/errores.log"

mkdir -p "$DIR"
> "$LOG_ERRORES"

PASO_ACTUAL=0
TOTAL_PASOS=11
FALLIDOS=0


# =====================================
# Funcion auxiliar para ejecutar pasos
# =====================================

ejecutar_paso() {
    local num="$1"
    local nombre="$2"
    shift 2

    PASO_ACTUAL=$((PASO_ACTUAL + 1))

    echo
    echo "================================================"
    echo "[$PASO_ACTUAL/$TOTAL_PASOS] $nombre"
    echo "================================================"

    "$@"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "[-] ERROR en paso $PASO_ACTUAL ($nombre) - Codigo: $exit_code"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] FALLO paso $PASO_ACTUAL ($nombre) - Codigo: $exit_code" >> "$LOG_ERRORES"
        FALLIDOS=$((FALLIDOS + 1))
    else
        echo "[+] OK"
    fi
}


# ==========================================================
#                    INICIO PIPELINE
# ==========================================================

echo
echo "############################################################"
echo "#  RECONOCIMIENTO OSINT - $DOMINIO"
echo "#  $(date '+%Y-%m-%d %H:%M:%S')"
echo "#  Resultados: $DIR"
echo "############################################################"


# -------------------------------------------
# [1/10] WHOIS NIC Bolivia
# -------------------------------------------

ejecutar_paso 1 "WHOIS NIC Bolivia" \
    bash "$SCRIPT_DIR/whois_bo.sh" "$DOMINIO"


# -------------------------------------------
# [2/10] Descubrimiento de subdominios
# -------------------------------------------

ejecutar_paso 2 "Descubrimiento de subdominios" \
    bash "$SCRIPT_DIR/todos_los_subdominios.sh" "$DOMINIO"


# -------------------------------------------
# [3/10] Analisis DNS
# -------------------------------------------

SUBDOMINIOS="$DIR/subdominios_${DOMINIO}.txt"

if [ ! -f "$SUBDOMINIOS" ]; then
    echo "[-] No existe archivo de subdominios, saltando DNS"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando DNS - no existe subdominios" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 3 "Analisis DNS" \
        bash "$SCRIPT_DIR/dnsx.sh" "$DOMINIO" "$SUBDOMINIOS"
fi


# -------------------------------------------
# [4/10] Analisis ASN
# -------------------------------------------

DNS_FILE="$DIR/dns_${DOMINIO}.txt"

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo DNS, saltando ASN"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando ASN - no existe dns" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 4 "Analisis ASN" \
        bash "$SCRIPT_DIR/asn.sh" "$DOMINIO" "$DNS_FILE"
fi


# -------------------------------------------
# [5/10] Analisis HTTP (httpx)
# -------------------------------------------

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo DNS, saltando HTTPX"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando HTTPX - no existe dns" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 5 "Analisis HTTP (httpx)" \
        bash "$SCRIPT_DIR/httpx.sh" "$DOMINIO" "$DNS_FILE"
fi


# -------------------------------------------
# [6/10] Security Headers
# -------------------------------------------

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo DNS, saltando Security Headers"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando Security Headers - no existe dns" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 6 "Security Headers" \
        bash "$SCRIPT_DIR/security_headers.sh" "$DOMINIO" "$DNS_FILE"
fi


# -------------------------------------------
# [7/10] Certificados SSL
# -------------------------------------------

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo DNS, saltando Certificados"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando Certificados - no existe dns" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 7 "Certificados SSL" \
        bash "$SCRIPT_DIR/certificados.sh" "$DOMINIO" "$DNS_FILE"
fi


# -------------------------------------------
# [8/11] Robots.txt
# -------------------------------------------

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo DNS, saltando Robots"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando Robots - no existe dns" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 8 "Robots.txt" \
        bash "$SCRIPT_DIR/robots.sh" "$DOMINIO" "$DNS_FILE"
fi


# -------------------------------------------
# [9/11] Wayback Machine
# -------------------------------------------

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo DNS, saltando Wayback"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando Wayback - no existe dns" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 9 "Wayback Machine" \
        bash "$SCRIPT_DIR/wayback.sh" "$DOMINIO" "$DNS_FILE"
fi


# -------------------------------------------
# [10/11] Katana Web Crawling + Filtro
# -------------------------------------------

if [ ! -f "$DNS_FILE" ]; then
    echo "[-] No existe archivo DNS, saltando Katana"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Saltando Katana - no existe dns" >> "$LOG_ERRORES"
    FALLIDOS=$((FALLIDOS + 1))
else
    ejecutar_paso 10 "Katana Web Crawling + Filtro" \
        bash "$SCRIPT_DIR/katana.sh" "$DOMINIO" "$DNS_FILE"
fi


# -------------------------------------------
# [11/11] Generar Reporte HTML
# -------------------------------------------

ejecutar_paso 11 "Generar Reporte HTML" \
    bash "$SCRIPT_DIR/generar_reporte.sh" "$DOMINIO"


# ==========================================================
#                    RESUMEN FINAL
# ==========================================================

echo
echo "############################################################"
echo "#  PROCESO COMPLETADO"
echo "#  $(date '+%Y-%m-%d %H:%M:%S')"
echo "############################################################"
echo
echo "Dominio  : $DOMINIO"
echo "Pasos    : $TOTAL_PASOS"
echo "Fallidos : $FALLIDOS"
echo
echo "Archivos generados:"
echo

if [ -d "$DIR" ]; then
    ls -1 "$DIR" 2>/dev/null | while read -r archivo; do
        echo "  $DIR/$archivo"
    done
fi

echo

if [ "$FALLIDOS" -gt 0 ]; then
    echo "[!] Hubo $FALLIDOS paso(s) con errores."
    echo "    Revisa el log: $LOG_ERRORES"
fi

echo
echo "[+] Listo."
