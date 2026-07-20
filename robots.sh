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
# Carpetas
# =====================================


DIR="resultados/$DOMINIO"

mkdir -p "$DIR"


SALIDA="$DIR/robots_$DOMINIO.txt"

TMP="/tmp/robots_hosts.txt"



# =====================================
# Extraer dominios válidos
# =====================================


echo "[+] Extrayendo hosts DNS..."



awk '
NR>6 && NF>0 {
print $1
}
' "$DNS_FILE" | sort -u > "$TMP"



TOTAL=$(wc -l < "$TMP")

echo "[+] Hosts encontrados: $TOTAL"

echo



# =====================================
# Crear reporte
# =====================================


cat > "$SALIDA" <<EOF

============================================================
                 ANALISIS ROBOTS.TXT
============================================================

Dominio principal:
$DOMINIO

Total hosts analizados:
$TOTAL


============================================================


EOF



# =====================================
# Analizar robots
# =====================================


while read -r HOST
do


    URL="https://$HOST/robots.txt"


    echo "[+] Revisando $HOST"



    HTTP_CODE=$(curl \
    -k \
    -s \
    -o /tmp/robots_actual.txt \
    -w "%{http_code}" \
    -L \
    --max-time 10 \
    "$URL")



    echo "
------------------------------------------------------------
HOST:
$HOST

URL:
$URL

Estado HTTP:
$HTTP_CODE
" >> "$SALIDA"



    if [ "$HTTP_CODE" = "200" ]; then


        echo "Contenido relevante:" >> "$SALIDA"

        grep -Ei \
        "^(User-agent|Disallow|Allow|Sitemap)" \
        /tmp/robots_actual.txt \
        >> "$SALIDA"



        echo >> "$SALIDA"


        echo "Encontrado robots.txt"



    else


        echo "No existe robots.txt accesible" >> "$SALIDA"



    fi



    echo "------------------------------------------------------------" >> "$SALIDA"


done < "$TMP"



# =====================================
# Limpieza
# =====================================

rm -f "$TMP"
rm -f /tmp/robots_actual.txt



echo
echo "[+] Reporte generado:"
echo "$SALIDA"
