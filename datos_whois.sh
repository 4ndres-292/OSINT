#!/bin/bash

INPUT="$1"
DOMINIO="$2"

DIR="resultados/$DOMINIO"
mkdir -p "$DIR"

SALIDA="$DIR/whois_${DOMINIO}.txt"

# Crear el encabezado del reporte
printf "==========================================\n" > "$SALIDA"
printf "           WHOIS NIC BOLIVIA\n" >> "$SALIDA"
printf "==========================================\n\n" >> "$SALIDA"
printf "Dominio consultado : %s\n\n" "$DOMINIO" >> "$SALIDA"

# Procesar el HTML y agregar el contenido al reporte
sed -e 's/&nbsp;//g' \
    -e 's/&aacute;/á/g' -e 's/&eacute;/é/g' -e 's/&iacute;/í/g' \
    -e 's/&oacute;/ó/g' -e 's/&uacute;/ú/g' -e 's/&ntilde;/ñ/g' \
    -e 's/&Aacute;/Á/g' -e 's/&Eacute;/É/g' -e 's/&Iacute;/Í/g' \
    -e 's/&Oacute;/Ó/g' -e 's/&Uacute;/Ú/g' -e 's/&Ntilde;/Ñ/g' \
    -e 's/<[^>]*>/\n/g' "$INPUT" | \
awk '

{
    gsub(/\r/, "")
    gsub(/^[ \t]+|[ \t]+$/, "")
}

$0 == "" { next }

/Titular del Dominio|Contacto Administrativo|Contacto T.+cnico|Contacto Financiero|Servidores DNS|Otros Datos/ {

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
