#!/bin/bash

INPUT="$1"
DOMINIO="$2"

SALIDA="whois_${DOMINIO}.txt"

# Crear el encabezado del reporte
printf "==========================================\n" > "$SALIDA"
printf "           WHOIS NIC BOLIVIA\n" >> "$SALIDA"
printf "==========================================\n\n" >> "$SALIDA"
printf "Dominio consultado : %s\n\n" "$DOMINIO" >> "$SALIDA"

# Procesar el HTML y agregar el contenido al reporte
sed -e 's/&nbsp;//g' \
    -e 's/<[^>]*>/\n/g' "$INPUT" | \
awk '

{
    gsub(/\r/, "")
    gsub(/^[ \t]+|[ \t]+$/, "")
}

$0 == "" { next }

/Titular del Dominio|Contacto Administrativo|Contacto Técnico|Contacto Financiero|Servidores DNS|Otros Datos/ {

    if ($0 !~ /:$/) {

        print ""
        print "=========================================="
        print $0
        print "=========================================="
        next

    }

}

/:$/ {

    gsub(/[ \t]*:[ \t]*$/, "")
    campo=$0

    do {

        if (getline <= 0)
            exit

        gsub(/\r/, "")
        gsub(/^[ \t]+|[ \t]+$/, "")

    } while($0=="")

    printf "%-25s : %s\n", campo, $0

}

' >> "$SALIDA"

printf "\n==========================================\n" >> "$SALIDA"

echo "[+] Reporte generado:"
echo "    $SALIDA"
