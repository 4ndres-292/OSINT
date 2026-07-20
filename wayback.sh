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


SALIDA="$DIR/wayback_$DOMINIO.txt"



TMP="/tmp/hosts_wayback.txt"




# =====================================
# Extraer subdominios válidos
# =====================================


awk '

NR>6 && NF>0 {

print $1

}

' "$DNS_FILE" | sort -u > "$TMP"



TOTAL=$(wc -l < "$TMP")


echo
echo "[+] Subdominios a analizar: $TOTAL"

echo
echo "[+] Consultando Wayback Machine..."



# =====================================
# Crear reporte
# =====================================


cat > "$SALIDA" <<EOF

============================================================
              WAYBACK MACHINE - $DOMINIO
============================================================


SUBDOMINIO                     URL HISTORICA
------------------------------------------------------------

EOF



# =====================================
# Consulta por cada host
# =====================================


while read -r HOST

do


    echo "[+] Analizando: $HOST"


    curl -s \
    "https://web.archive.org/cdx/search/cdx?url=$HOST/*&output=json&fl=original,statuscode,mimetype&filter=statuscode:200&collapse=urlkey" \
    > /tmp/wayback_host.json



    if [ -s /tmp/wayback_host.json ]; then


        python3 <<EOF >> "$SALIDA"

import json


host="$HOST"


try:

    with open("/tmp/wayback_host.json") as f:
        datos=json.load(f)


    for item in datos[1:]:

        url=item[0]
        codigo=item[1]
        tipo=item[2]

        print(f"{host:<35} {codigo:<8} {tipo:<30} {url}")


except:

    pass


EOF


    fi


done < "$TMP"



# =====================================
# Limpieza
# =====================================


sort -u "$SALIDA" -o "$SALIDA"


rm -f "$TMP"
rm -f /tmp/wayback_host.json



echo
echo "[+] Reporte generado:"
echo "$SALIDA"
