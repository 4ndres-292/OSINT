#!/bin/bash


DOMINIO="$1"


if [ -z "$DOMINIO" ]; then
    echo "Uso: $0 dominio"
    echo "Ejemplo: $0 minedu.gob.bo"
    exit 1
fi


# =====================================
# Directorios
# =====================================

CARPETA="resultados/$DOMINIO"

mkdir -p "$CARPETA"


echo "[+] Descubriendo subdominios de: $DOMINIO"



# =====================================
# Subfinder
# =====================================

echo
echo "[+] Ejecutando Subfinder..."

subfinder \
-d "$DOMINIO" \
-silent \
-o "$CARPETA/subfinder.txt"


if [ -f "$CARPETA/subfinder.txt" ]; then
    echo "    encontrados: $(wc -l < "$CARPETA/subfinder.txt")"
fi



# =====================================
# Assetfinder
# =====================================

echo
echo "[+] Ejecutando Assetfinder..."


assetfinder \
--subs-only "$DOMINIO" \
> "$CARPETA/assetfinder.txt"


if [ -f "$CARPETA/assetfinder.txt" ]; then
    echo "    encontrados: $(wc -l < "$CARPETA/assetfinder.txt")"
fi




# =====================================
# crt.sh
# =====================================

echo
echo "[+] Consultando crt.sh..."


curl -s \
"https://crt.sh/?q=%25.$DOMINIO&output=json" \
| jq -r '.[].name_value' \
| sed 's/\*\.//g' \
| sort -u \
> "$CARPETA/crtsh.txt"



if [ -f "$CARPETA/crtsh.txt" ]; then
    echo "    encontrados: $(wc -l < "$CARPETA/crtsh.txt")"
fi





# =====================================
# Amass pasivo
# =====================================

echo
echo "[+] Ejecutando Amass pasivo..."


amass enum \
-passive \
-d "$DOMINIO" \
-o "$CARPETA/amass.txt"



if [ -f "$CARPETA/amass.txt" ]; then
    echo "    encontrados: $(wc -l < "$CARPETA/amass.txt")"
fi





# =====================================
# Findomain
# =====================================

echo
echo "[+] Ejecutando Findomain..."


findomain \
-t "$DOMINIO" \
-u "$CARPETA/findomain.txt"



if [ -f "$CARPETA/findomain.txt" ]; then
    echo "    encontrados: $(wc -l < "$CARPETA/findomain.txt")"
fi





# =====================================
# Unificar resultados
# =====================================


echo
echo "[+] Unificando resultados..."

cat \
"$CARPETA/subfinder.txt" \
"$CARPETA/assetfinder.txt" \
"$CARPETA/crtsh.txt" \
"$CARPETA/amass.txt" \
"$CARPETA/findomain.txt" \
2>/dev/null \
| sed '/^$/d' \
| sort -u \
> "$CARPETA/subdominios_$DOMINIO.txt"



TOTAL=$(wc -l < "$CARPETA/subdominios_$DOMINIO.txt")



echo
echo "======================================"
echo "[+] Proceso terminado"
echo "[+] Total subdominios únicos: $TOTAL"
echo "[+] Archivo generado:"
echo "    $CARPETA/subdominios_$DOMINIO.txt"
echo "======================================"
