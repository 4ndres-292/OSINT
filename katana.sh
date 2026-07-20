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



SALIDA="$DIR/katana_$DOMINIO.txt"



TMP="/tmp/katana_hosts.txt"



# =====================================
# Extraer hosts válidos
# =====================================


awk '

NR>6 && NF>0 {

print $1

}

' "$DNS_FILE" | sort -u > "$TMP"



TOTAL=$(wc -l < "$TMP")


echo
echo "[+] Hosts para crawling: $TOTAL"



# =====================================
# Crear URLs
# =====================================


sed 's#^#https://#' "$TMP" > /tmp/katana_urls.txt



echo
echo "[+] Ejecutando Katana..."
echo



# =====================================
# Ejecutar Katana
# =====================================


katana \
-list /tmp/katana_urls.txt \
-c 10 \
-depth 3 \
-js-crawl \
-silent \
-automatic-form-fill \
-o /tmp/katana_raw.txt



if [ ! -s /tmp/katana_raw.txt ]; then

    echo "[-] No se encontraron URLs"

    rm -f "$TMP"
    exit 1

fi



# =====================================
# Reporte final
# =====================================


cat > "$SALIDA" <<EOF

============================================================
              KATANA WEB CRAWLING - $DOMINIO
============================================================


URLS DESCUBIERTAS

------------------------------------------------------------

EOF



cat /tmp/katana_raw.txt | sort -u >> "$SALIDA"



TOTAL_URL=$(wc -l < /tmp/katana_raw.txt)



echo
echo "[+] URLs encontradas: $TOTAL_URL"

echo
echo "[+] Reporte generado:"
echo "$SALIDA"



rm -f "$TMP"
rm -f /tmp/katana_urls.txt
rm -f /tmp/katana_raw.txt
