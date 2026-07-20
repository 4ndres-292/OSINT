#!/bin/bash


DOMINIO="$1"
LISTA="$2"


# ==============================
# Validaciones
# ==============================

if [ -z "$DOMINIO" ] || [ -z "$LISTA" ]; then
    echo "Uso:"
    echo "$0 dominio archivo_subdominios"
    echo
    echo "Ejemplo:"
    echo "$0 minedu.gob.bo subdominios.txt"
    exit 1
fi


if [ ! -f "$LISTA" ]; then
    echo "[-] No existe archivo:"
    echo "$LISTA"
    exit 1
fi



# ==============================
# Carpetas y salida
# ==============================

DIR="resultados/$DOMINIO"

mkdir -p "$DIR"


SALIDA="$DIR/dns_$DOMINIO.txt"



echo "[+] Analizando DNS de $DOMINIO"
echo



# ==============================
# Obtener registros DNS
# ==============================


echo "[+] Consultando subdominios..."

dnsx \
-l "$LISTA" \
-a \
-aaaa \
-cname \
-resp \
-silent \
-no-color \
> /tmp/dnsx_subdominios.txt



echo "[+] Consultando registros del dominio principal..."

echo "$DOMINIO" | dnsx \
-mx \
-txt \
-ns \
-soa \
-resp \
-silent \
-no-color \
> /tmp/dnsx_dominio.txt



# Unir resultados

cat /tmp/dnsx_subdominios.txt \
/tmp/dnsx_dominio.txt \
> /tmp/dnsx_raw.txt



if [ ! -s /tmp/dnsx_raw.txt ]; then

    echo "[-] No se encontraron registros DNS"
    exit 1

fi



# ==============================
# Crear reporte limpio
# ==============================


cat > "$SALIDA" <<EOF

============================================================
              ANALISIS DNS - $DOMINIO
============================================================


SUBDOMINIO                              TIPO        VALOR
------------------------------------------------------------

EOF



while read -r linea
do

    HOST=$(echo "$linea" | awk '{print $1}')


    TIPO=$(echo "$linea" | \
    grep -oE '\[[A-Za-z0-9]+\]' | \
    tr -d '[]')


    VALOR=$(echo "$linea" | \
    awk -F'] ' '{print $2}')



    if [ -n "$HOST" ] && [ -n "$TIPO" ]; then

        printf "%-40s %-10s %s\n" \
        "$HOST" \
        "$TIPO" \
        "$VALOR" \
        >> "$SALIDA"

    fi


done < /tmp/dnsx_raw.txt



# ==============================
# Limpieza temporal
# ==============================

rm -f /tmp/dnsx_raw.txt
rm -f /tmp/dnsx_subdominios.txt
rm -f /tmp/dnsx_dominio.txt



echo
echo "[+] Reporte generado:"
echo "    $SALIDA"
