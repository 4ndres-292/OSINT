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
# Carpetas
# ==============================

DIR="resultados/$DOMINIO"

mkdir -p "$DIR"


SALIDA="$DIR/dns_$DOMINIO.txt"



echo "[+] Analizando DNS de $DOMINIO"
echo


# ==============================
# Ejecutar dnsx
# ==============================


dnsx \
-l "$LISTA" \
-a \
-aaaa \
-cname \
-mx \
-txt \
-resp \
-silent | \
sed -r 's/\x1B\[[0-9;]*[mK]//g' \
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


DOMINIO                 SUBDOMINIO                          TIPO        VALOR
--------------------------------------------------------------------------

EOF



while read -r linea
do

    HOST=$(echo "$linea" | awk '{print $1}')
    
    TIPO=$(echo "$linea" | grep -oE '\[[A-Z]+\]' | tr -d '[]')
    
    VALOR=$(echo "$linea" | sed -E 's/.*\] //' )


    printf "%-23s %-38s %-10s %s\n" \
    "$DOMINIO" \
    "$HOST" \
    "$TIPO" \
    "$VALOR" \
    >> "$SALIDA"


done < /tmp/dnsx_raw.txt



rm -f /tmp/dnsx_raw.txt



echo
echo "[+] Reporte generado:"
echo "$SALIDA"
