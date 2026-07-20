#!/bin/bash


DOMINIO="$1"

INPUT="resultados/$DOMINIO/katana_$DOMINIO.txt"

SALIDA="resultados/$DOMINIO/katana_filtrado_$DOMINIO.txt"



if [ ! -f "$INPUT" ]; then

echo "No existe:"
echo "$INPUT"

exit 1

fi



echo "[+] Filtrando URLs..."



cat "$INPUT" | \

grep -Ei \
'admin|login|api|swagger|auth|user|panel|dashboard|config|backup|upload|download|token|xml|json' \
| \

grep -Ev \
'\.(jpg|jpeg|png|gif|svg|css|woff|woff2|ttf|ico|mp4|mp3)$' \
| \

grep -Ev \
'[A-Za-z0-9+/]{40,}={0,2}' \
| \

sort -u \
> "$SALIDA"



TOTAL=$(wc -l < "$SALIDA")



echo
echo "[+] URLs filtradas:"
echo "$TOTAL"

echo
echo "[+] Resultado:"
echo "$SALIDA"
