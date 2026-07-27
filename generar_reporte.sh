#!/bin/bash

# ==========================================================
# generar_reporte.sh - Genera reporte HTML para defensa academica
#
# Uso: ./generar_reporte.sh dominio.gob.bo
# Sale: resultados/$dominio/reporte_$dominio.html
# ==========================================================

DOMINIO="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIR="$SCRIPT_DIR/resultados/$DOMINIO"
SALIDA="$DIR/reporte_${DOMINIO}.html"
FECHA=$(date '+%d/%m/%Y')
FECHA_HORA=$(date '+%d/%m/%Y %H:%M')

if [ -z "$DOMINIO" ]; then
    echo "Uso: $0 dominio"
    echo "Ejemplo: $0 minedu.gob.bo"
    exit 1
fi

if [ ! -d "$DIR" ]; then
    echo "[-] No existe la carpeta de resultados: $DIR"
    exit 1
fi

echo "[+] Generando reporte para: $DOMINIO"

# ==========================================================
# Funciones auxiliares de parseo
# ==========================================================

# Contar subdominios
TOTAL_SUBS=0
F_SUB="$DIR/subdominios_${DOMINIO}.txt"
if [ -f "$F_SUB" ] && [ -s "$F_SUB" ]; then
    TOTAL_SUBS=$(wc -l < "$F_SUB")
fi

# Contar IPs unicas del ASN
TOTAL_IPS=0
F_ASN="$DIR/asn_${DOMINIO}.txt"
if [ -f "$F_ASN" ]; then
    TOTAL_IPS=$(awk '/^IP/ { found=1; next } found && /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { count++ } /^=/ { found=0 } END { print count+0 }' "$F_ASN")
fi

# Contar registros DNS (todas las lineas de registros, unicos por subdominio+tipo+valor)
TOTAL_DNS=0
F_DNS="$DIR/dns_${DOMINIO}.txt"
if [ -f "$F_DNS" ]; then
    TOTAL_DNS=$(awk 'NR>9 && NF>=3 {print $1, $2}' "$F_DNS" | sort -u | wc -l)
fi

# Contar hosts HTTP activos
TOTAL_HTTP=0
F_HTTPX="$DIR/httpx_${DOMINIO}.txt"
if [ -f "$F_HTTPX" ]; then
    TOTAL_HTTP=$(awk 'NR>7 && NF>=2 {print $1}' "$F_HTTPX" | wc -l)
fi

# Contar hosts analizados en security headers y calcular score promedio
TOTAL_SH=0
SCORE_PROM=0
F_SH="$DIR/security_headers_${DOMINIO}.txt"
if [ -f "$F_SH" ]; then
    TOTAL_SH=$(awk 'NR>16 && /^[a-z]/ && /\// {count++} END {print count}' "$F_SH")
    SUMA_SCORES=$(awk 'NR>16 && /^[a-z]/ && /\// {
        s=0
        if ($2=="SI") s+=2
        if ($3=="SI") s+=2
        if ($4=="SI") s+=1
        if ($5=="SI") s+=1
        if ($6=="SI") s+=1
        if ($7=="SI") s+=1
        sum+=s; count++
    } END {print sum+0}' "$F_SH")
    if [ "$TOTAL_SH" -gt 0 ] 2>/dev/null; then
        SCORE_PROM=$(awk "BEGIN {printf \"%.1f\", $SUMA_SCORES / $TOTAL_SH}")
    fi
fi

# Contar certificados y proximos a vencer (<30 dias)
TOTAL_CERTS=0
CERTS_PROXIMOS=0
F_CERT="$DIR/certificados_${DOMINIO}.txt"
if [ -f "$F_CERT" ]; then
    TOTAL_CERTS=$(awk 'NR>7 && NF>=4 {print $1}' "$F_CERT" | wc -l)
    CERTS_PROXIMOS=$(awk 'NR>7 && NF>=4 {
        dias=$NF
        if (dias+0 < 0 || dias+0 <= 30) count++
    } END {print count+0}' "$F_CERT")
fi

# Contar robots.txt encontrados
ROBOTS_TOTAL=0
ROBOTS_200=0
ROBOTS_404=0
ROBOTS_ERR=0
ROBOTS_SITEMAP=0
ROBOTS_DISALLOW=0
ROBOTS_FULLBLOCK=0
ROBOTS_EMPTY=0
F_ROBOTS="$DIR/robots_${DOMINIO}.txt"
if [ -f "$F_ROBOTS" ]; then
    ROBOTS_TOTAL=$(awk '/^HOST:/ {count++} END {print count+0}' "$F_ROBOTS")
    ROBOTS_200=$(awk '/Estado HTTP:/ {getline; if ($0 ~ /^200$/) count++} END {print count+0}' "$F_ROBOTS")
    ROBOTS_404=$(awk '/Estado HTTP:/ {getline; if ($0 ~ /^404$/) count++} END {print count+0}' "$F_ROBOTS")
    ROBOTS_ERR=$(awk '/Estado HTTP:/ {getline; if ($0 !~ /^(200|404)$/) count++} END {print count+0}' "$F_ROBOTS")
    ROBOTS_SITEMAP=$(awk '/^HOST:/ {host=$0; sm=0; dis=0; fb=0; empty=1; st=""}
/Estado HTTP:/ {getline; st=$0}
/Sitemap:/ && st=="200" {sm=1; empty=0}
/^Disallow: .+/ && st=="200" {dis++; empty=0}
/^Disallow: \/$/ && st=="200" {fb=1; empty=0}
/^---$/ {
    if (sm==1) sitemap_hosts++
    if (dis>0) disallow_hosts++
    if (fb==1) fullblock_hosts++
    if (st=="200" && empty==1) empty_hosts++
}
END {
    printf "%d %d %d %d", sitemap_hosts+0, disallow_hosts+0, fullblock_hosts+0, empty_hosts+0
}' "$F_ROBOTS")
    read ROBOTS_SITEMAP ROBOTS_DISALLOW ROBOTS_FULLBLOCK ROBOTS_EMPTY <<< "$ROBOTS_SITEMAP"
fi

# Contar URLs historicas wayback
TOTAL_WAYBACK=0
TOTAL_WB_SUBS=0
TOTAL_WB_MIMES=0
F_WAYBACK="$DIR/wayback_${DOMINIO}.txt"
if [ -f "$F_WAYBACK" ]; then
    TOTAL_WAYBACK=$(awk 'NR>8 && NF>=3 && $1 !~ /^=/ && $1 !~ /^Sub/' "$F_WAYBACK" | wc -l)
    TOTAL_WB_SUBS=$(awk 'NR>8 && NF>=3 && $1 !~ /^=/ && $1 !~ /^Sub/ {print $1}' "$F_WAYBACK" | sort -u | wc -l)
    TOTAL_WB_MIMES=$(awk 'NR>8 && NF>=3 && $1 !~ /^=/ && $1 !~ /^Sub/ {print $NF}' "$F_WAYBACK" | sort -u | wc -l)
fi

# Contar URLs katana
TOTAL_KATANA=0
TOTAL_KATANA_FIL=0
F_KATANA="$DIR/katana_${DOMINIO}.txt"
F_KATFIL="$DIR/katana_filtrado_${DOMINIO}.txt"
if [ -f "$F_KATANA" ]; then
    TOTAL_KATANA=$(awk '/^http/ {count++} END {print count+0}' "$F_KATANA")
fi
if [ -f "$F_KATFIL" ]; then
    TOTAL_KATANA_FIL=$(wc -l < "$F_KATFIL")
fi

# Contar tecnologías únicas detectadas por httpx
TOTAL_TECHS=0
if [ -f "$F_HTTPX" ]; then
    TOTAL_TECHS=$(awk 'NR>7 && /^https/ && /\[/ {
        # Extract last bracket group (technologies)
        line=$0
        # Find all [...] groups
        n=split(line, parts, "[")
        for (i=n; i>=2; i--) {
            gsub(/\]/, "", parts[i])
            gsub(/^[ \t]+|[ \t]+$/, "", parts[i])
            if (parts[i] ~ /[A-Za-z]/ && parts[i] !~ /^[0-9]+$/ && parts[i] !~ /^[0-9]{3}$/) {
                # This is likely the tech group
                m=split(parts[i], tarr, ",")
                for (t=1; t<=m; t++) {
                    gsub(/^[ \t]+|[ \t]+$/, "", tarr[t])
                    if (tarr[t] != "") techs[tarr[t]]=1
                }
                break
            }
        }
    } END {print length(techs)+0}' "$F_HTTPX")
fi

# Contar hosts sin HSTS
SH_NO_HSTS=0
if [ -f "$F_SH" ]; then
    SH_NO_HSTS=$(awk 'NR>16 && /^[a-z]/ && /\// {if ($2=="NO") count++} END {print count+0}' "$F_SH")
fi

# Contar hosts con CSP y XFO (del header del archivo)
SH_CSP=0; SH_XFO=0
if [ -f "$F_SH" ]; then
    SH_CSP=$(awk '/Content-Security-Policy/ {print $NF}' "$F_SH")
    SH_XFO=$(awk '/X-Frame-Options/ {print $NF}' "$F_SH")
fi

# Contar certificados vencidos (días negativos)
CERTS_VENCIDOS=0
if [ -f "$F_CERT" ]; then
    CERTS_VENCIDOS=$(awk 'NR>7 && NF>=4 {dias=$NF; if (dias+0 < 0) count++} END {print count+0}' "$F_CERT")
fi

# Contar hosts con cabeceras débiles (score <= 2/8)
ZERO_COUNT=0
if [ -f "$F_SH" ]; then
    ZERO_COUNT=$(awk 'NR>16 && /^[a-z]/ && /\// {
        s=0
        if ($2=="SI") s+=2
        if ($3=="SI") s+=2
        if ($4=="SI") s+=1
        if ($5=="SI") s+=1
        if ($6=="SI") s+=1
        if ($7=="SI") s+=1
        if (s <= 2) count++
    } END {print count+0}' "$F_SH")
fi

# ==========================================================
# WHOIS - raw text for JavaScript parsing
# ==========================================================

WHOIS_RAW=""
F_WHOIS="$DIR/whois_${DOMINIO}.txt"
if [ -f "$F_WHOIS" ] && [ -s "$F_WHOIS" ]; then
    WHOIS_RAW=$(cat "$F_WHOIS")
fi


# ==========================================================
# ASN - agrupados por ASN
# ==========================================================

ASN_HTML=""
ASN_COUNT=0
if [ -f "$F_ASN" ]; then
    ASN_COUNT=$(awk '/^ASN *:/ {gsub(/^ASN *: */, ""); print}' "$F_ASN" | sort -u | wc -l)
    ASN_HTML=$(awk '
/^IP *:/ {
    gsub(/^IP *: */, ""); ip=$0
    getline; gsub(/^ASN *: */, ""); asn=$0
    getline; gsub(/^Organizaci[oó]n *: */, ""); org=$0
    getline; gsub(/^Pa[ií]s *: */, ""); pais=$0
    getline; gsub(/^Ciudad *: */, ""); ciudad=$0
    ips[asn] = ips[asn] ? ips[asn] "\n" ip : ip
    orgs[asn] = org
    paises[asn] = pais
    ciudades[asn] = ciudad
}
END {
    n=0
    for (a in ips) { asns[++n]=a }
    for (i=1; i<=n; i++) {
        a=asns[i]
        gsub(/&/, "\\&amp;", orgs[a])
        gsub(/</, "\\&lt;", orgs[a])
        split(ips[a], iplist, "\n")
        nip=length(iplist)
        printf "<div class=\"asn-card\">"
        printf "<div class=\"asn-header\">"
        printf "<div class=\"asn-id\">%s</div>", a
        printf "<div class=\"asn-org\">%s</div>", orgs[a]
        printf "</div>"
        printf "<div class=\"asn-meta\"><span>Pa&iacute;s: %s</span><span>Ciudad: %s</span></div>", paises[a], ciudades[a]
        printf "<div class=\"asn-ips-title\">IPs encontradas (%d)</div>", nip
        printf "<div class=\"asn-ip-list\">"
        for (j=1; j<=nip; j++) printf "<div class=\"asn-ip\">%s</div>", iplist[j]
        printf "</div>"
        printf "</div>"
    }
}
' "$F_ASN")
fi

# ==========================================================
# DNS - todos los registros activos
# ==========================================================

DNS_TABLA=""
DNS_COUNT=0
if [ -f "$F_DNS" ]; then
    DNS_COUNT=$(awk 'NR>9 && NF>=3 {print $1, $2}' "$F_DNS" | sort -u | wc -l)
    DNS_TABLA=$(awk 'NR>9 && NF>=3 {
    host=$1; tipo=$2
    val=$0; sub(/^\S+ +[A-Z]+ +/, "", val)
    gsub(/^\[/, "", val); gsub(/\]$/, "", val)
    printf "%s\t%s\t%s\n", host, tipo, val
}' "$F_DNS" | sort -u | awk -F'\t' 'BEGIN {
    print "<table class=\"data-table\"><thead><tr><th style=\"width:50px\">#</th><th>Subdominio</th><th>Tipo</th><th>Valor</th></tr></thead><tbody>"
}
NF>=3 { printf "<tr><td>%d</td><td class=\"mono\">%s</td><td><span class=\"badge badge-blue\">%s</span></td><td class=\"mono\">%s</td></tr>\n", NR, $1, $2, $3 }
END { print "</tbody></table>" }')
fi

# ==========================================================
# HTTPX - extraer tecnologias (bracket format)
# ==========================================================

HTTPX_TABLA=""
if [ -f "$F_HTTPX" ]; then
    HTTPX_TABLA=$(awk 'BEGIN { idx=0 }
NR>7 && /^\[/ { next }
NF>=2 && $1 ~ /^https?:/ {
    idx++
    url=$1
    gsub(/^https?:\/\//, "", url)
    status="-"; size="-"; titulo="-"; tech="-"
    n=split($0, parts, "[")
    for (i=2; i<=n; i++) {
        gsub(/\]/, "", parts[i])
        gsub(/^[ \t]+|[ \t]+$/, "", parts[i])
        if (parts[i] ~ /^[0-9]{3}$/ && status == "-") status=parts[i]
        else if (parts[i] ~ /^[0-9]+$/ && size == "-") size=parts[i]
        else if (size != "-" && titulo == "-") titulo=parts[i]
        else if (titulo != "-") {
            tech=parts[i]
            for (j=i+1; j<=n; j++) { gsub(/\]/, "", parts[j]); gsub(/^[ \t]+|[ \t]+$/, "", parts[j]); if (parts[j] != "") tech=tech","parts[j] }
            break
        }
    }
    if (titulo == "-" || titulo == "") titulo="Sin t&iacute;tulo"
    if (size == "-" || size == "") size="-"
    if (tech == "-" || tech == "") tech="<span class=\"text-muted\">No detectado</span>"
    else {
        split(tech, tarr, ",")
        tech=""
        for (t in tarr) {
            gsub(/^[ \t]+|[ \t]+$/, "", tarr[t])
            if (tarr[t] != "") tech=tech"<span class=\"badge badge-blue\">"tarr[t]"</span> "
        }
    }
    color=""
    if (status ~ /^2/) color="color-green"
    else if (status ~ /^3/) color="color-yellow"
    else if (status ~ /^[45]/) color="color-red"
    printf "<tr><td>%d</td><td class=\"mono\">%s</td><td class=\"%s\">%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", idx, url, color, status, size, titulo, tech
}
' "$F_HTTPX")
    HTTPX_TABLA="<table class=\"data-table\"><thead><tr><th style=\"width:50px\">#</th><th>Host</th><th>HTTP</th><th>Tama&ntilde;o</th><th>T&iacute;tulo</th><th>Tecnolog&iacute;as</th></tr></thead><tbody>
${HTTPX_TABLA}
</tbody></table>"
fi

# ==========================================================
# SECURITY HEADERS - explanations, compliance, sorted table
# ==========================================================

SH_EXPLAIN_HTML=""
SH_COMPLIANCE_HTML=""
SH_TABLA=""
SH_RESUMEN=""
if [ -f "$F_SH" ]; then

    # --- Header explanations ---
    SH_EXPLAIN_HTML='<div class="sh-explain">
<div class="sh-explain-item"><div class="sh-abbr">HSTS</div><div class="sh-full">(HTTP Strict Transport Security)</div><div class="sh-desc">Obliga al navegador a utilizar HTTPS evitando ataques SSL Strip.</div></div>
<div class="sh-explain-item"><div class="sh-abbr">CSP</div><div class="sh-full">(Content Security Policy)</div><div class="sh-desc">Reduce ataques XSS limitando desde d&oacute;nde puede cargarse contenido.</div></div>
<div class="sh-explain-item"><div class="sh-abbr">XFO</div><div class="sh-full">(X-Frame-Options)</div><div class="sh-desc">Evita ataques de Clickjacking impidiendo que el sitio sea cargado dentro de un iframe.</div></div>
<div class="sh-explain-item"><div class="sh-abbr">XCTO</div><div class="sh-full">(X-Content-Type-Options)</div><div class="sh-desc">Impide que el navegador interprete incorrectamente el tipo de contenido.</div></div>
<div class="sh-explain-item"><div class="sh-abbr">RP</div><div class="sh-full">(Referrer-Policy)</div><div class="sh-desc">Controla la informaci&oacute;n enviada en el encabezado Referer.</div></div>
<div class="sh-explain-item"><div class="sh-abbr">PP</div><div class="sh-full">(Permissions-Policy)</div><div class="sh-desc">Controla qu&eacute; funcionalidades del navegador est&aacute;n permitidas.</div></div>
</div>'

    # --- Compliance summary (count from actual data rows) ---
    SH_COMPLIANCE_HTML=$(awk '
    BEGIN { hsts=0; csp=0; xfo=0; xcto=0; rp=0; pp=0; total=0 }
    NR>16 && /^[a-z]/ && /\// {
        total++
        if ($2 == "SI") hsts++
        if ($3 == "SI") csp++
        if ($4 == "SI") xfo++
        if ($5 == "SI") xcto++
        if ($6 == "SI") rp++
        if ($7 == "SI") pp++
    }
    END {
        if (total == 0) exit
        printf "<div class=\"sh-compliance\">"
        printf "<div class=\"sh-compliance-item\"><div class=\"sh-comp-name\">HSTS</div><div class=\"sh-comp-count\">%d/%d</div><div class=\"sh-comp-label\">presentes</div></div>", hsts, total
        printf "<div class=\"sh-compliance-item\"><div class=\"sh-comp-name\">CSP</div><div class=\"sh-comp-count\">%d/%d</div><div class=\"sh-comp-label\">presentes</div></div>", csp, total
        printf "<div class=\"sh-compliance-item\"><div class=\"sh-comp-name\">XFO</div><div class=\"sh-comp-count\">%d/%d</div><div class=\"sh-comp-label\">presentes</div></div>", xfo, total
        printf "<div class=\"sh-compliance-item\"><div class=\"sh-comp-name\">XCTO</div><div class=\"sh-comp-count\">%d/%d</div><div class=\"sh-comp-label\">presentes</div></div>", xcto, total
        printf "<div class=\"sh-compliance-item\"><div class=\"sh-comp-name\">RP</div><div class=\"sh-comp-count\">%d/%d</div><div class=\"sh-comp-label\">presentes</div></div>", rp, total
        printf "<div class=\"sh-compliance-item\"><div class=\"sh-comp-name\">PP</div><div class=\"sh-comp-count\">%d/%d</div><div class=\"sh-comp-label\">presentes</div></div>", pp, total
        printf "</div>"
    }
    ' "$F_SH")

    # --- Sorted table (least secure first, score computed from SI/NO with real weights) ---
    SH_TABLA=$(awk '
    NR>16 && /^[a-z]/ && /\// {
        host=$1; hsts=$2; csp=$3; xfo=$4; xcto=$5; rp=$6; pp=$7

        score_num=0
        if (hsts=="SI") score_num+=2
        if (csp=="SI") score_num+=2
        if (xfo=="SI") score_num+=1
        if (xcto=="SI") score_num+=1
        if (rp=="SI") score_num+=1
        if (pp=="SI") score_num+=1

        row_class=""
        if (score_num <= 2) row_class="row-danger"
        else if (score_num >= 6) row_class="row-success"
        else if (score_num >= 4) row_class="row-warning"

        if (score_num >= 6) score_badge="<span class=\"badge-score-green\">"score_num"/8</span>"
        else if (score_num >= 4) score_badge="<span class=\"badge-score-yellow\">"score_num"/8</span>"
        else if (score_num >= 2) score_badge="<span class=\"badge-score-orange\">"score_num"/8</span>"
        else score_badge="<span class=\"badge-score-red\">"score_num"/8</span>"

        val_SI="<span class=\"badge badge-green\">SI</span>"
        val_NO="<span class=\"badge badge-red\">NO</span>"
        h_html=(hsts=="SI") ? val_SI : val_NO
        c_html=(csp=="SI") ? val_SI : val_NO
        x_html=(xfo=="SI") ? val_SI : val_NO
        t_html=(xcto=="SI") ? val_SI : val_NO
        r_html=(rp=="SI") ? val_SI : val_NO
        p_html=(pp=="SI") ? val_SI : val_NO

        rows[NR] = score_num
        data[NR] = sprintf("<tr class=\"%s\"><td class=\"mono\">%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", row_class, host, h_html, c_html, x_html, t_html, r_html, p_html, score_badge)
        idx[NR] = NR
    }
    END {
        n = 0
        for (k in rows) { n++; si[n] = k }
        for (i=1; i<=n; i++) {
            for (j=i+1; j<=n; j++) {
                if (rows[si[j]] < rows[si[i]]) {
                    tmp = si[i]; si[i] = si[j]; si[j] = tmp
                }
            }
        }
        print "<table class=\"data-table\"><thead><tr><th>Host</th><th>HSTS</th><th>CSP</th><th>XFO</th><th>XCTO</th><th>RP</th><th>PP</th><th>Score</th></tr></thead><tbody>"
        for (i=1; i<=n; i++) printf "%s", data[si[i]]
        print "</tbody></table>"
    }
    ' "$F_SH")

    # --- Summary stat cards (from header counts) ---
    SH_RESUMEN=$(awk '
    /Hosts analizados/ { hosts=$NF }
    /Strict-Transport-Security/ { hsts=$NF }
    /Content-Security-Policy/ { csp=$NF }
    /X-Frame-Options/ { xfo=$NF }
    /X-Content-Type-Options/ { xcto=$NF }
    /Referrer-Policy/ { rp=$NF }
    /Permissions-Policy/ { pp=$NF }
    END {
        printf "<div class=\"stats-grid\">"
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Hosts Analizados</div></div>", hosts
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Con HSTS</div></div>", hsts
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Con CSP</div></div>", csp
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Con XFO</div></div>", xfo
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Con XCTO</div></div>", xcto
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Con Referrer-Policy</div></div>", rp
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Con Permissions-Policy</div></div>", pp
        printf "</div>"
    }
    ' "$F_SH")
fi

CERT_TABLA=""
if [ -f "$F_CERT" ]; then
    CERT_TABLA=$(awk '
    NR>7 && NF>=4 {
        host=$1
        emisor=$2
        fecha=""
        dias=""
        for (i=3; i<=NF; i++) {
            if ($i ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) { fecha=$i; dias=$(i+1); break }
        }
        if (fecha == "") next

        dias_num=dias+0
        dias_class=""
        if (dias_num < 0) dias_class="color-red"
        else if (dias_num <= 30) dias_class="color-red"
        else if (dias_num <= 60) dias_class="color-yellow"
        else dias_class="color-green"

        n++
        sort_key[n] = dias_num
        data[n] = sprintf("<tr><td class=\"mono\">%s</td><td>%s</td><td>%s</td><td class=\"%s\"><strong>%d</strong></td></tr>\n", host, emisor, fecha, dias_class, dias_num)
    }
    END {
        if (n == 0) exit
        for (i=1; i<=n; i++) idx[i] = i
        for (i=1; i<=n; i++) {
            for (j=i+1; j<=n; j++) {
                if (sort_key[idx[j]] < sort_key[idx[i]]) {
                    tmp = idx[i]; idx[i] = idx[j]; idx[j] = tmp
                }
            }
        }
        print "<table class=\"data-table\"><thead><tr><th>Host</th><th>Emisor</th><th>Vence</th><th>D&iacute;as Restantes</th></tr></thead><tbody>"
        for (i=1; i<=n; i++) printf "%s", data[idx[i]]
        print "</tbody></table>"
    }
    ' "$F_CERT")
fi

ROBOTS_HTML=""
ROBOTS_TABLE=""
ROBOTS_CONCLUSIONES=""
if [ -f "$F_ROBOTS" ]; then

    # Parse each host block: extract host, status, rules
    # Priority: 1=full block, 2=restricted dirs, 3=sitemap, 4=empty, 5=no findings/no robots
    ROBOTS_HTML=$(awk 'BEGIN { OFS="" }
    /^HOST:/ {
        host=$0; sub(/^HOST: */, "", host)
        has_robots=0; status=""; hasDisallow=0; disallow_count=0
        hasFullBlock=0; hasSitemap=0; sitemap_url=""; isEmpty=1
        disallow_rules=""; is_error=0
    }
    /^Estado HTTP:/ {
        getline; status=$0
        if (status != "200" && status != "404") is_error=1
    }
    /^Disallow: \/$/ && status=="200" {
        hasFullBlock=1; hasDisallow=1; disallow_count++; isEmpty=0
        if (disallow_rules != "") disallow_rules=disallow_rules"\n"
        disallow_rules=disallow_rules"Disallow: /"
    }
    /^Disallow: .+/ && status=="200" && $0 !~ /^Disallow: \/$/ {
        hasDisallow=1; disallow_count++; isEmpty=0
        rule=$0; gsub(/^Disallow: */, "Disallow: ", rule)
        if (disallow_rules != "") disallow_rules=disallow_rules"\n"
        disallow_rules=disallow_rules rule
    }
    /^Sitemap:/ && status=="200" {
        hasSitemap=1; sitemap_url=$0; sub(/^Sitemap: */, "", sitemap_url); isEmpty=0
    }
    /^Allow:/ && status=="200" { isEmpty=0 }
    /^User-agent:/ && status=="200" { isEmpty=0 }
    /^Crawl-delay:/ && status=="200" { isEmpty=0 }
    /^---$/ {
        n++
        hosts[n]=host
        statuses[n]=status
        fullblock[n]=hasFullBlock
        disallow_n[n]=disallow_count
        sitemap[n]=hasSitemap
        sitemap_u[n]=sitemap_url
        empty_flag[n]=isEmpty
        err_flag[n]=is_error

        if (status != "200" && status != "404") pri[n]=6
        else if (status == "404") pri[n]=5
        else if (hasFullBlock) pri[n]=1
        else if (hasDisallow) pri[n]=2
        else if (hasSitemap) pri[n]=3
        else if (isEmpty) pri[n]=4
        else pri[n]=5

        rules[n]=disallow_rules
    }
    END {
        if (n==0) exit

        for (i=1; i<=n; i++) idx[i]=i
        for (i=1; i<=n; i++) {
            for (j=i+1; j<=n; j++) {
                if (pri[idx[j]] < pri[idx[i]]) {
                    tmp=idx[i]; idx[i]=idx[j]; idx[j]=tmp
                }
            }
        }

        # Findings cards
        for (i=1; i<=n; i++) {
            k=idx[i]
            if (pri[k] >= 5 && statuses[k] == "200") continue
            if (statuses[k] != "200" && statuses[k] != "404") continue

            find_class="info"
            find_title=""
            find_rules=""

            if (pri[k]==1) {
                find_class="finding-item"
                find_title="Bloqueo completo del rastreo"
                find_rules=rules[k]
            } else if (pri[k]==2) {
                find_class="finding-item warning"
                find_title="Directorios internos restringidos"
                find_rules=rules[k]
            } else if (pri[k]==3) {
                find_class="finding-item info"
                find_title="Publicaci&oacute;n de Sitemap"
                find_rules=sitemap_u[k]
            } else if (pri[k]==4) {
                find_class="finding-item info"
                find_title="robots.txt vac&iacute;o"
            } else if (pri[k]==5 && statuses[k]=="404") {
                find_class="finding-item warning"
                find_title="Sin robots.txt (HTTP 404)"
            }

            if (find_title == "") continue

            printf "<div class=\"%s\">", find_class
            printf "<h4>%s</h4>", find_title
            printf "<p><strong>Host:</strong> <span class=\"mono\">%s</span></p>", hosts[k]
            printf "<p><strong>Estado HTTP:</strong> %s</p>", statuses[k]
            if (find_rules != "") {
                gsub(/\n/, "<br>", find_rules)
                printf "<p><strong>Reglas detectadas:</strong></p>"
                printf "<pre class=\"code-block\" style=\"max-height:none;white-space:pre-wrap;\">%s</pre>", find_rules
            }
            printf "</div>"
        }
    }
    ' "$F_ROBOTS")

    # Summary table
    ROBOTS_TABLE=$(awk '
    /^HOST:/ {
        host=$0; sub(/^HOST: */, "", host)
        hasDisallow=0; disallow_count=0; hasFullBlock=0
        hasSitemap=0; sitemap_url=""; isEmpty=1; status=""
    }
    /^Estado HTTP:/ { getline; status=$0 }
    /^Disallow: \/$/ && status=="200" { hasFullBlock=1; hasDisallow=1; disallow_count++; isEmpty=0 }
    /^Disallow: .+/ && status=="200" && $0 !~ /^Disallow: \/$/ { hasDisallow=1; disallow_count++; isEmpty=0 }
    /^Sitemap:/ && status=="200" { hasSitemap=1; sitemap_url=$0; sub(/^Sitemap: */, "", sitemap_url); isEmpty=0 }
    /^Allow:/ && status=="200" { isEmpty=0 }
    /^User-agent:/ && status=="200" { isEmpty=0 }
    /^Crawl-delay:/ && status=="200" { isEmpty=0 }
    /^---$/ {
        n++
        hosts[n]=host; statuses[n]=status
        fullblock[n]=hasFullBlock; disallow_n[n]=disallow_count
        sitemap[n]=hasSitemap; sitemap_u[n]=sitemap_url; empty_flag[n]=isEmpty

        if (status != "200" && status != "404") pri[n]=6
        else if (status == "404") pri[n]=5
        else if (hasFullBlock) pri[n]=1
        else if (hasDisallow) pri[n]=2
        else if (hasSitemap) pri[n]=3
        else if (isEmpty) pri[n]=4
        else pri[n]=5
    }
    END {
        if (n==0) exit
        for (i=1; i<=n; i++) idx[i]=i
        for (i=1; i<=n; i++) {
            for (j=i+1; j<=n; j++) {
                if (pri[idx[j]] < pri[idx[i]]) { tmp=idx[i]; idx[i]=idx[j]; idx[j]=tmp }
            }
        }
        print "<table class=\"data-table\"><thead><tr><th style=\"width:50px\">#</th><th>Host</th><th>HTTP</th><th>Hallazgo</th><th>Resumen</th></tr></thead><tbody>"
        tbl_n=0
        for (i=1; i<=n; i++) {
            k=idx[i]
            if (pri[k] >= 5 && statuses[k] == "200") continue
            if (statuses[k] != "200" && statuses[k] != "404") continue
            tbl_n++
            hallazgo=""; resumen=""
            if (pri[k]==1) { hallazgo="Bloqueo completo"; resumen="Disallow: /" }
            else if (pri[k]==2) { hallazgo="Directorios internos"; resumen=disallow_n[k]" reglas Disallow" }
            else if (pri[k]==3) { hallazgo="Sitemap"; resumen="1 sitemap encontrado" }
            else if (pri[k]==4) { hallazgo="robots.txt vac&iacute;o"; resumen="Sin reglas" }
            else if (pri[k]==5 && statuses[k]=="404") { hallazgo="Sin robots.txt"; resumen="HTTP 404" }
            if (hallazgo == "") continue
            row_class=""
            if (pri[k]==1) row_class="row-danger"
            else if (pri[k]==2) row_class="row-warning"
            printf "<tr class=\"%s\"><td>%d</td><td class=\"mono\">%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", row_class, tbl_n, hosts[k], statuses[k], hallazgo, resumen
        }
        print "</tbody></table>"
    }
    ' "$F_ROBOTS")

    # Conclusions
    ROBOTS_CONCLUSIONES="<p>Se analizaron <strong>${ROBOTS_TOTAL}</strong> hosts.</p>"
    if [ "${ROBOTS_200:-0}" -gt 0 ]; then
        ROBOTS_CONCLUSIONES="${ROBOTS_CONCLUSIONES}<p><strong>${ROBOTS_200}</strong> publican un archivo robots.txt accesible.</p>"
    fi
    if [ "${ROBOTS_DISALLOW:-0}" -gt 0 ]; then
        ROBOTS_CONCLUSIONES="${ROBOTS_CONCLUSIONES}<p><strong>${ROBOTS_DISALLOW}</strong> exponen directorios mediante reglas Disallow.</p>"
    fi
    if [ "${ROBOTS_SITEMAP:-0}" -gt 0 ]; then
        ROBOTS_CONCLUSIONES="${ROBOTS_CONCLUSIONES}<p><strong>${ROBOTS_SITEMAP}</strong> publican uno o m&aacute;s Sitemap.</p>"
    fi
    if [ "${ROBOTS_FULLBLOCK:-0}" -gt 0 ]; then
        ROBOTS_CONCLUSIONES="${ROBOTS_CONCLUSIONES}<p><strong>${ROBOTS_FULLBLOCK}</strong> bloquean completamente el rastreo mediante Disallow: /.</p>"
    fi
    ROBOTS_CONCLUSIONES="${ROBOTS_CONCLUSIONES}<p>En t&eacute;rminos generales, la mayor&iacute;a de los servicios no exponen informaci&oacute;n sensible mediante robots.txt.</p>"
fi

# ==========================================================
# WAYBACK - análisis ejecutivo
# ==========================================================

WB_MIME_TABLA=""
WB_CAT_TABLA=""
WB_SUBS_TABLA=""
WB_CONCLUSIONES=""
WB_C_ADMIN=0; WB_C_AUTH=0; WB_C_API=0; WB_C_DOCS=0; WB_C_BACKUP=0
WB_C_CONFIG=0; WB_C_UPLOADS=0; WB_C_DOWNLOADS=0
WB_C_WELLKNOWN=0; WB_C_ROBOTS=0; WB_C_SITEMAPS=0
if [ -f "$F_WAYBACK" ]; then

    # 1. Tabla distribución MIME (campo $3 = mimetype real)
    WB_MIME_TABLA=$(awk 'NR>8 && NF>=3 && $1 !~ /^=/ && $1 !~ /^Sub/ {
        tipo=$3; count[tipo]++
    }
    END {
        n=0
        for (t in count) { n++; types[n]=t; counts[n]=count[t] }
        for (i=1; i<=n; i++) {
            for (j=i+1; j<=n; j++) {
                if (counts[j] > counts[i]) {
                    tmp=types[i]; types[i]=types[j]; types[j]=tmp
                    tmpc=counts[i]; counts[i]=counts[j]; counts[j]=tmpc
                }
            }
        }
        print "<table class=\"data-table\"><thead><tr><th>Tipo MIME</th><th style=\"width:100px\">Cantidad</th></tr></thead><tbody>"
        for (i=1; i<=n; i++) {
            printf "<tr><td class=\"mono\">%s</td><td><strong>%d</strong></td></tr>\n", types[i], counts[i]
        }
        print "</tbody></table>"
    }
    ' "$F_WAYBACK")

    # 2. Top 10 subdominios con mayor actividad histórica
    WB_SUBS_TABLA=$(awk 'NR>8 && NF>=3 && $1 !~ /^=/ && $1 !~ /^Sub/ {
        subs[$1]++
    }
    END {
        n=0
        for (s in subs) { n++; sarr[n]=s; scounts[n]=subs[s] }
        for (i=1; i<=n; i++) {
            for (j=i+1; j<=n; j++) {
                if (scounts[j] > scounts[i]) {
                    tmp=sarr[i]; sarr[i]=sarr[j]; sarr[j]=tmp
                    tmpc=scounts[i]; scounts[i]=scounts[j]; scounts[j]=tmpc
                }
            }
        }
        MAX=10; if (n<MAX) MAX=n
        print "<table class=\"data-table\"><thead><tr><th>Subdominio</th><th style=\"width:140px\">Recursos hist&oacute;ricos</th></tr></thead><tbody>"
        for (i=1; i<=MAX; i++) {
            printf "<tr><td class=\"mono\">%s</td><td><strong>%d</strong></td></tr>\n", sarr[i], scounts[i]
        }
        print "</tbody></table>"
    }
    ' "$F_WAYBACK")

    # 3. Conteo por categoría (11 categorías, solo contadores)
    WB_CAT_DATA=$(awk '
    BEGIN {
        c_admin=0; c_auth=0; c_api=0; c_docs=0; c_backup=0
        c_config=0; c_uploads=0; c_downloads=0
        c_wellknown=0; c_robots=0; c_sitemaps=0
    }
    NR>8 && NF>=3 && $1 !~ /^=/ && $1 !~ /^Sub/ {
        url=""
        for (i=2; i<=NF; i++) { if ($i ~ /^http/) { url=$i; break } }
        if (url == "") next
        actual=url
        if (match(actual, /\/web\/[^\/]+\//)) {
            after_wb=substr(actual, RSTART+RLENGTH)
            if (after_wb ~ /^https?:\/\//) { actual=after_wb }
            else { gsub(/^https?:\/\/[^\/]+\/web\/[^\/]+\//, "", actual) }
        }
        path=actual
        gsub(/^https?:\/\/[^\/]+/, "", path)
        lp=tolower(path)
        if (lp ~ /\/(admin|login|panel|dashboard|cpanel|wp-admin|wp-login|phpmyadmin|manager|console)/) c_admin++
        if (lp ~ /\/(auth|sso|oauth|signin|signup|register|session)/) c_auth++
        if (lp ~ /\/(api|swagger|graphql|openapi|rest|soap|webservice|wsdl)/ || lp ~ /\?api/ || lp ~ /\.api\./) c_api++
        if (lp ~ /\.(pdf|doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|rtf)$/) c_docs++
        if (lp ~ /\.(zip|rar|7z|bak|sql|tar\.gz|db|dump|old|orig|backup)$/) c_backup++
        if (lp ~ /\.well-known/) c_wellknown++
        if (lp ~ /\/robots\.txt/) c_robots++
        if (lp ~ /\/sitemap\.xml|sitemap.*\.xml/) c_sitemaps++
        if (lp ~ /\.well-known/ || lp ~ /assetlinks\.json/ || lp ~ /ai-plugin\.json/ || lp ~ /robots\.txt/ || lp ~ /sitemap\.xml/ || lp ~ /security\.txt/ || lp ~ /humans\.txt/) c_config++
        if (lp ~ /\/(upload|uploads|files|media|attachments)\//) c_uploads++
        if (lp ~ /\/(download|downloads)\//) c_downloads++
    }
    END {
        printf "%d %d %d %d %d %d %d %d %d %d %d", c_admin, c_auth, c_api, c_docs, c_backup, c_config, c_uploads, c_downloads, c_wellknown, c_robots, c_sitemaps
    }
    ' "$F_WAYBACK")
    read WB_C_ADMIN WB_C_AUTH WB_C_API WB_C_DOCS WB_C_BACKUP WB_C_CONFIG WB_C_UPLOADS WB_C_DOWNLOADS WB_C_WELLKNOWN WB_C_ROBOTS WB_C_SITEMAPS <<< "$WB_CAT_DATA"

    # Tabla HTML de categorías
    WB_CAT_TOTAL=$((WB_C_ADMIN+WB_C_AUTH+WB_C_API+WB_C_DOCS+WB_C_BACKUP+WB_C_CONFIG+WB_C_UPLOADS+WB_C_DOWNLOADS+WB_C_WELLKNOWN+WB_C_ROBOTS+WB_C_SITEMAPS))
    if [ "$WB_CAT_TOTAL" -gt 0 ]; then
        WB_CAT_TABLA="<table class=\"data-table\"><thead><tr><th>Categor&iacute;a</th><th style=\"width:100px\">Cantidad</th></tr></thead><tbody>"
        [ "$WB_C_ADMIN" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Administraci&oacute;n</td><td><strong>${WB_C_ADMIN}</strong></td></tr>"
        [ "$WB_C_AUTH" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Autenticaci&oacute;n</td><td><strong>${WB_C_AUTH}</strong></td></tr>"
        [ "$WB_C_API" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>APIs</td><td><strong>${WB_C_API}</strong></td></tr>"
        [ "$WB_C_DOCS" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Documentaci&oacute;n</td><td><strong>${WB_C_DOCS}</strong></td></tr>"
        [ "$WB_C_BACKUP" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Backups</td><td><strong>${WB_C_BACKUP}</strong></td></tr>"
        [ "$WB_C_CONFIG" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Configuraciones</td><td><strong>${WB_C_CONFIG}</strong></td></tr>"
        [ "$WB_C_UPLOADS" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Uploads</td><td><strong>${WB_C_UPLOADS}</strong></td></tr>"
        [ "$WB_C_DOWNLOADS" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Downloads</td><td><strong>${WB_C_DOWNLOADS}</strong></td></tr>"
        [ "$WB_C_WELLKNOWN" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Well-known</td><td><strong>${WB_C_WELLKNOWN}</strong></td></tr>"
        [ "$WB_C_ROBOTS" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Robots.txt</td><td><strong>${WB_C_ROBOTS}</strong></td></tr>"
        [ "$WB_C_SITEMAPS" -gt 0 ] && WB_CAT_TABLA="${WB_CAT_TABLA}<tr><td>Sitemaps</td><td><strong>${WB_C_SITEMAPS}</strong></td></tr>"
        WB_CAT_TABLA="${WB_CAT_TABLA}</tbody></table>"
    fi

    # 4. Conclusiones automáticas
    TOP_MIME=$(awk 'NR>8 && NF>=3 && $1 !~ /^=/ && $1 !~ /^Sub/ {tipo=$3; count[tipo]++} END {
        n=0; for (t in count) {n++; arr[n]=t; c[n]=count[t]}
        for (i=1; i<=n; i++) for (j=i+1; j<=n; j++) if (c[j]>c[i]) {tmp=arr[i];arr[i]=arr[j];arr[j]=tmp;tmpc=c[i];c[i]=c[j];c[j]=tmpc}
        if (n>=2) printf "%s y %s", arr[1], arr[2]
        else if (n==1) printf "%s", arr[1]
    }' "$F_WAYBACK")
    WB_CONCLUSIONES=""
    WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se identificaron <strong>${TOTAL_WAYBACK}</strong> URLs hist&oacute;ricas archivadas.</p>"
    WB_CONCLUSIONES="${WB_CONCLUSIONES}<p><strong>${TOTAL_WB_SUBS}</strong> subdominios poseen registros en Wayback Machine.</p>"
    [ -n "$TOP_MIME" ] && WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Los recursos corresponden principalmente a <strong>${TOP_MIME}</strong>.</p>"
    [ "${WB_C_ADMIN:-0}" -gt 0 ] && WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se detectaron <strong>${WB_C_ADMIN}</strong> endpoints administrativos hist&oacute;ricos.</p>"
    [ "${WB_C_AUTH:-0}" -gt 0 ] && WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se localizaron <strong>${WB_C_AUTH}</strong> endpoints de autenticaci&oacute;n hist&oacute;ricos.</p>"
    [ "${WB_C_API:-0}" -gt 0 ] && WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se encontraron <strong>${WB_C_API}</strong> APIs hist&oacute;ricas.</p>"
    [ "${WB_C_DOCS:-0}" -gt 0 ] && WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se identificaron <strong>${WB_C_DOCS}</strong> documentos p&uacute;blicos.</p>"
    [ "${WB_C_CONFIG:-0}" -gt 0 ] && WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se detectaron <strong>${WB_C_CONFIG}</strong> archivos de configuraci&oacute;n.</p>"
    if [ "${WB_C_BACKUP:-0}" -gt 0 ]; then
        WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se encontraron <strong>${WB_C_BACKUP}</strong> archivos hist&oacute;ricos de respaldo.</p>"
    fi
    [ "${WB_C_UPLOADS:-0}" -gt 0 ] && WB_CONCLUSIONES="${WB_CONCLUSIONES}<p>Se localizaron <strong>${WB_C_UPLOADS}</strong> directorios de subida de archivos.</p>"
    if [ "$WB_CAT_TOTAL" -eq 0 ]; then
        WB_CONCLUSIONES="<p>No se observaron recursos hist&oacute;ricos relevantes.</p>"
    fi
fi

KATFIL_HTML=""
K_C_AUTH=0; K_C_ADMIN=0; K_C_API=0; K_C_CONFIG=0; K_C_BACKUP=0; K_C_DOCS=0; K_C_MON=0; K_C_VPN=0; K_C_OTHER=0
if [ -f "$F_KATFIL" ]; then
    KATANA_HOSTS=$(awk -F/ '{gsub(/:.*/, "", $3); print $3}' "$F_KATFIL" | sort -u | wc -l)
    KATFIL_HTML=$(awk -v dom="$DOMINIO" -v tot_hosts="$KATANA_HOSTS" -v tot_urls="$TOTAL_KATANA_FIL" '
    BEGIN {
        n=0; na=0; ntot=0
        ca=0; cb=0; cc=0; cd=0; ce=0; cf=0; cg=0; ch=0; ci=0
    }
    NF>0 {
        url=$0
        # Extract host (strip protocol and path)
        h=url
        gsub(/^https?:\/\//, "", h)
        gsub(/\/.*$/, "", h)
        # Extract path
        p=url
        gsub(/^https?:\/\/[^\/]+/, "", p)
        if (p == "") p="/"
        lp=tolower(p)
        lh=tolower(h)

        # Classify
        cat=""
        if (lp ~ /\/(admin|administrator|dashboard|panel|cpanel)/ || lh ~ /^admin\./) { cat="Administracion"; ca++ }
        else if (lp ~ /\/(login|logout|auth|signin|signup|oauth|sso|realms|registro)/ || lh ~ /^(auth|sso|login)\./) { cat="Autenticacion"; cb++ }
        else if (lp ~ /\/(api|swagger|docs|graphql|openapi)/ || lp ~ /\/v[0-9]+\// || lh ~ /^api\./) { cat="APIs"; cc++ }
        else if (lp ~ /\/(config|settings|\.env|\.well-known)/ || lp ~ /\.config/) { cat="Configuracion"; cd++ }
        else if (lp ~ /\/(backup|dump|db|sql|zip|bak)/ || lp ~ /\.(sql|bak|zip|db|dump)$/) { cat="Respaldos"; ce++ }
        else if (lp ~ /\/(upload|download|files|storage)/) { cat="Archivos"; cf++ }
        else if (lp ~ /\/(grafana|prometheus|monitor|metrics|health)/ || lh ~ /^(grafana|monitoring)\./) { cat="Monitoreo"; cg++ }
        else if (lp ~ /\/(vpn|remote|rdp)/ || lh ~ /^(vpn|remote)\./) { cat="VPN"; ch++ }
        else if (lp ~ /\/(docs|manual|wiki)/) { cat="Documentacion"; ci++ }
        else { cat="Otros" }

        n++
        hosts[n]=h; paths[n]=p; cats[n]=cat
    }
    END {
        # --- Stat cards ---
        printf "<div class=\"stats-grid\">"
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">URLs analizadas</div></div>", tot_urls
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%s</div><div class=\"stat-label\">Hosts analizados</div></div>", tot_hosts
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%d</div><div class=\"stat-label\">Rutas relevantes</div></div>", n
        ncat=0
        if (ca>0) ncat++
        if (cb>0) ncat++
        if (cc>0) ncat++
        if (cd>0) ncat++
        if (ce>0) ncat++
        if (cf>0) ncat++
        if (cg>0) ncat++
        if (ch>0) ncat++
        if (ci>0) ncat++
        printf "<div class=\"stat-card\"><div class=\"stat-value\">%d</div><div class=\"stat-label\">Categorias detectadas</div></div>", ncat
        printf "</div>"

        # --- Category summary table (sorted by count desc) ---
        nc=0
        if (ca>0) { nc++; cn[nc]="Administracion"; cc_[nc]=ca; cp[nc]="&#128737;" }
        if (cb>0) { nc++; cn[nc]="Autenticacion"; cc_[nc]=cb; cp[nc]="&#128274;" }
        if (cc>0) { nc++; cn[nc]="APIs"; cc_[nc]=cc; cp[nc]="&#128268;" }
        if (cd>0) { nc++; cn[nc]="Configuracion"; cc_[nc]=cd; cp[nc]="&#9881;" }
        if (ce>0) { nc++; cn[nc]="Respaldos"; cc_[nc]=ce; cp[nc]="&#128451;" }
        if (cf>0) { nc++; cn[nc]="Archivos"; cc_[nc]=cf; cp[nc]="&#128193;" }
        if (cg>0) { nc++; cn[nc]="Monitoreo"; cc_[nc]=cg; cp[nc]="&#128200;" }
        if (ch>0) { nc++; cn[nc]="VPN/Acceso Remoto"; cc_[nc]=ch; cp[nc]="&#128272;" }
        if (ci>0) { nc++; cn[nc]="Documentacion"; cc_[nc]=ci; cp[nc]="&#128214;" }
        # Sort desc by count
        for (i=1; i<=nc; i++) idx[i]=i
        for (i=1; i<=nc; i++) for (j=i+1; j<=nc; j++) if (cc_[idx[j]]>cc_[idx[i]]) { tmp=idx[i];idx[i]=idx[j];idx[j]=tmp }

        printf "<h3 style=\"margin:25px 0 15px;color:var(--primary);font-size:1.1em;\">&#128202; Resumen por Categoria</h3>"
        printf "<table class=\"data-table\"><thead><tr><th>Categoria</th><th style=\"width:110px\">Cantidad</th></tr></thead><tbody>"
        for (i=1; i<=nc; i++) printf "<tr><td>%s %s</td><td><strong>%d</strong></td></tr>\n", cp[idx[i]], cn[idx[i]], cc_[idx[i]]
        printf "</tbody></table>"

        # --- Findings: most interesting endpoints (auth, admin, api, mon, vpn first) ---
        printf "<h3 style=\"margin:25px 0 15px;color:var(--primary);font-size:1.1em;\">&#9888; Hallazgos Relevantes</h3>"
        printf "<div class=\"findings\">"
        fn=0
        for (i=1; i<=n; i++) {
            c=cats[i]
            if (c=="Autenticacion" || c=="Administracion" || c=="APIs" || c=="Monitoreo" || c=="VPN" || c=="Respaldos" || c=="Configuracion") {
                fn++
                fi[fn]=i
            }
        }
        # Sort findings by category priority
        for (i=1; i<=fn; i++) for (j=i+1; j<=fn; j++) {
            pi=cats[fi[i]]; pj=cats[fi[j]]
            pri_i=0; pri_j=0
            if (pi=="Administracion") pri_i=1
            else if (pi=="Autenticacion") pri_i=2
            else if (pi=="APIs") pri_i=3
            else if (pi=="Monitoreo") pri_i=4
            else if (pi=="VPN") pri_i=5
            else if (pi=="Configuracion") pri_i=6
            else if (pi=="Respaldos") pri_i=7
            if (pj=="Administracion") pri_j=1
            else if (pj=="Autenticacion") pri_j=2
            else if (pj=="APIs") pri_j=3
            else if (pj=="Monitoreo") pri_j=4
            else if (pj=="VPN") pri_j=5
            else if (pj=="Configuracion") pri_j=6
            else if (pj=="Respaldos") pri_j=7
            if (pri_j < pri_i) { tmp=fi[i];fi[i]=fi[j];fi[j]=tmp }
        }
        MAX_FIND=5
        shown=0
        for (i=1; i<=fn; i++) {
            if (shown >= MAX_FIND) {
                printf "<p class=\"text-muted\">+ %d hallazgos adicionales (ver evidencia completa en TXT)</p>", fn-MAX_FIND
                break
            }
            k=fi[i]
            cls="info"
            if (cats[k]=="Administracion") cls="warning"
            else if (cats[k]=="Respaldos") cls=""
            else if (cats[k]=="Configuracion") cls="info"
            printf "<div class=\"finding-item %s\"><h4>%s</h4>", cls, cats[k]
            printf "<p><span class=\"mono\">%s</span> &mdash; <span class=\"mono\">%s</span></p>", hosts[k], paths[k]
            printf "</div>"
            shown++
        }
        printf "</div>"

        # --- Conclusions ---
        printf "<h3 style=\"margin:25px 0 15px;color:var(--primary);font-size:1.1em;\">&#128161; Conclusiones</h3>"
        printf "<div style=\"padding:15px 20px;background:var(--bg);border-radius:8px;border:1px solid var(--border);\">"
        if (cb>0) printf "<p>Se identificaron <strong>%d</strong> rutas relacionadas con autenticaci&oacute;n.</p>", cb
        if (ca>0) printf "<p>Se detectaron <strong>%d</strong> endpoints administrativos.</p>", ca
        if (cc>0) printf "<p>Se localizaron <strong>%d</strong> APIs documentadas.</p>", cc
        if (cg>0) printf "<p>Se encontraron <strong>%d</strong> servicios de monitoreo.</p>", cg
        if (cd>0) printf "<p>Se detectaron <strong>%d</strong> endpoints relacionados con configuraci&oacute;n.</p>", cd
        if (ch>0) printf "<p>Se identificaron <strong>%d</strong> servicios de acceso remoto.</p>", ch
        if (ce>0) printf "<p>Se localizaron <strong>%d</strong> endpoints de respaldos/dumps.</p>", ce
        if (cf>0) printf "<p>Se detectaron <strong>%d</strong> endpoints de gesti&oacute;n de archivos.</p>", cf
        printf "</div>"
    }
    ' "$F_KATFIL")
fi

cat > "$SALIDA" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>REPORTE OSINT</title>
<style>
:root {
    --primary: #1a365d;
    --primary-light: #2c5282;
    --accent: #2b6cb0;
    --bg: #f7fafc;
    --card-bg: #ffffff;
    --text: #2d3748;
    --text-muted: #718096;
    --border: #e2e8f0;
    --danger: #c53030;
    --danger-bg: #fff5f5;
    --warning: #d69e2e;
    --warning-bg: #fffff0;
    --success: #276749;
    --success-bg: #f0fff4;
    --blue-bg: #ebf8ff;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; }
.cover { background: linear-gradient(135deg, var(--primary) 0%, var(--primary-light) 50%, var(--accent) 100%); color: white; padding: 80px 40px; text-align: center; min-height: 400px; display: flex; flex-direction: column; justify-content: center; align-items: center; }
.cover h1 { font-size: 2.8em; margin-bottom: 10px; letter-spacing: 2px; }
.cover .subtitle { font-size: 1.3em; opacity: 0.9; margin-bottom: 30px; }
.cover .domain { font-size: 2em; font-family: 'Consolas', 'Fira Code', monospace; background: rgba(255,255,255,0.15); padding: 15px 40px; border-radius: 8px; margin: 20px 0; }
.cover .meta { font-size: 1em; opacity: 0.8; margin-top: 20px; }
.cover .shield { font-size: 4em; margin-bottom: 20px; }
.container { max-width: 1200px; margin: 0 auto; padding: 40px 20px; }
.section { background: var(--card-bg); border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 30px; overflow: hidden; }
.section-header { background: var(--primary); color: white; padding: 20px 30px; font-size: 1.3em; font-weight: 600; }
.section-body { padding: 30px; }
.stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 15px; margin-bottom: 25px; }
.stat-card { background: var(--bg); border-radius: 10px; padding: 20px; text-align: center; border: 1px solid var(--border); }
.stat-value { font-size: 2.2em; font-weight: 700; color: var(--primary); }
.stat-label { font-size: 0.85em; color: var(--text-muted); margin-top: 5px; }
.stat-card.danger .stat-value { color: var(--danger); }
.stat-card.warning .stat-value { color: var(--warning); }
.stat-card.success .stat-value { color: var(--success); }
.data-table { width: 100%; border-collapse: collapse; font-size: 0.9em; }
.data-table th { background: var(--primary); color: white; padding: 12px 15px; text-align: left; font-weight: 600; position: sticky; top: 0; }
.data-table td { padding: 10px 15px; border-bottom: 1px solid var(--border); }
.data-table tr:hover { background: var(--blue-bg); }
.data-table tr:nth-child(even) { background: #f8fafc; }
.data-table tr:nth-child(even):hover { background: var(--blue-bg); }
.row-danger { background: var(--danger-bg) !important; }
.row-danger:hover { background: #fed7d7 !important; }
.row-success { background: var(--success-bg) !important; }
.row-success:hover { background: #c6f6d5 !important; }
.row-warning { background: var(--warning-bg) !important; }
.row-warning:hover { background: #fefcbf !important; }
.badge { padding: 3px 10px; border-radius: 12px; font-size: 0.8em; font-weight: 600; display: inline-block; }
.badge-green { background: #c6f6d5; color: #276749; }
.badge-red { background: #fed7d7; color: #c53030; }
.badge-blue { background: #bee3f8; color: #2a4365; }
.color-green { color: var(--success); font-weight: 700; }
.color-red { color: var(--danger); font-weight: 700; }
.color-yellow { color: var(--warning); font-weight: 700; }
.mono { font-family: 'Consolas', 'Fira Code', monospace; font-size: 0.85em; }
.code-block { background: #1a202c; color: #e2e8f0; padding: 20px; border-radius: 8px; overflow-x: auto; font-family: 'Consolas', monospace; font-size: 0.85em; line-height: 1.5; white-space: pre-wrap; word-break: break-all; max-height: 400px; overflow-y: auto; }
.text-muted { color: var(--text-muted); font-style: italic; }
.tech-cell { font-size: 0.8em; color: var(--text-muted); max-width: 250px; }
.url-cell { word-break: break-all; font-size: 0.8em; }
.robot-block { margin-bottom: 20px; border: 1px solid var(--border); border-radius: 8px; padding: 15px; }
.robot-block h4 { color: var(--primary); margin-bottom: 10px; }
.table-scroll { max-height: 500px; overflow-y: auto; border: 1px solid var(--border); border-radius: 8px; }
.table-scroll .data-table { margin: 0; }
.findings { margin-top: 20px; }
.finding-item { padding: 15px 20px; border-left: 4px solid var(--danger); background: var(--danger-bg); margin-bottom: 10px; border-radius: 0 8px 8px 0; }
.finding-item.warning { border-left-color: var(--warning); background: var(--warning-bg); }
.finding-item.info { border-left-color: var(--accent); background: var(--blue-bg); }
.finding-item h4 { margin-bottom: 5px; }
.finding-item p { color: var(--text-muted); font-size: 0.9em; }
.footer { text-align: center; padding: 40px; color: var(--text-muted); font-size: 0.85em; border-top: 1px solid var(--border); margin-top: 40px; }
.whois-table { width: 100%; border-collapse: collapse; font-size: 0.9em; margin-bottom: 5px; }
.whois-table th { background: var(--primary); color: white; padding: 12px 15px; text-align: left; font-weight: 600; }
.whois-table td { padding: 10px 15px; border-bottom: 1px solid var(--border); vertical-align: top; word-break: break-word; }
.whois-table tr:nth-child(even) { background: #f8fafc; }
.whois-table tr:hover { background: var(--blue-bg); }
.whois-table td:first-child { font-weight: 600; color: var(--primary-light); white-space: nowrap; width: 220px; }
.whois-section-title { font-size: 1.1em; font-weight: 700; color: var(--primary); margin: 25px 0 12px 0; padding-bottom: 8px; border-bottom: 2px solid var(--accent); display: flex; align-items: center; gap: 8px; }
.whois-section-title:first-child { margin-top: 0; }
.whois-ns-list { list-style: none; padding: 0; margin: 0; }
.whois-ns-list li { padding: 8px 15px; border-bottom: 1px solid var(--border); font-family: 'Consolas', 'Fira Code', monospace; font-size: 0.9em; display: flex; align-items: center; gap: 8px; }
.whois-ns-list li:last-child { border-bottom: none; }
.whois-ns-list li::before { content: ''; display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: var(--accent); flex-shrink: 0; }
.whois-ns-box { border: 1px solid var(--border); border-radius: 8px; overflow: hidden; margin-bottom: 5px; }
.whois-status-list { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 5px; }
.whois-badge { padding: 5px 14px; border-radius: 20px; font-size: 0.85em; font-weight: 600; display: inline-block; }
.whois-badge-active { background: #c6f6d5; color: #276749; }
.whois-badge-info { background: #bee3f8; color: #2a4365; }
.whois-badge-warning { background: #fefcbf; color: #975a16; }
.asn-card { border: 1px solid var(--border); border-radius: 10px; margin-bottom: 20px; overflow: hidden; }
.asn-header { background: var(--primary); color: white; padding: 15px 20px; display: flex; align-items: center; gap: 15px; }
.asn-id { font-family: 'Consolas', 'Fira Code', monospace; font-size: 1.1em; font-weight: 700; background: rgba(255,255,255,0.15); padding: 4px 12px; border-radius: 6px; }
.asn-org { font-size: 1em; font-weight: 500; }
.asn-meta { padding: 10px 20px; display: flex; gap: 30px; font-size: 0.9em; color: var(--text-muted); border-bottom: 1px solid var(--border); }
.asn-ips-title { padding: 10px 20px 5px; font-weight: 600; font-size: 0.9em; color: var(--primary); }
.asn-ip-list { padding: 0 20px 15px; }
.asn-ip { font-family: 'Consolas', 'Fira Code', monospace; font-size: 0.85em; padding: 4px 0; border-bottom: 1px solid var(--border); }
.asn-ip:last-child { border-bottom: none; }
.section-tool { font-size: 0.8em; color: rgba(255,255,255,0.7); font-weight: 400; margin-top: 4px; }
.sh-explain { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 12px; margin-bottom: 25px; }
.sh-explain-item { background: var(--bg); border: 1px solid var(--border); border-radius: 8px; padding: 14px 18px; border-left: 4px solid var(--accent); }
.sh-explain-item .sh-abbr { font-family: 'Consolas', 'Fira Code', monospace; font-weight: 700; color: var(--primary); font-size: 1.05em; }
.sh-explain-item .sh-full { font-size: 0.8em; color: var(--text-muted); font-style: italic; margin-top: 2px; }
.sh-explain-item .sh-desc { font-size: 0.88em; color: var(--text); margin-top: 6px; line-height: 1.4; }
.sh-compliance { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-bottom: 25px; }
.sh-compliance-item { background: var(--bg); border: 1px solid var(--border); border-radius: 8px; padding: 12px; text-align: center; }
.sh-compliance-item .sh-comp-name { font-family: 'Consolas', 'Fira Code', monospace; font-weight: 700; color: var(--primary); font-size: 0.95em; }
.sh-compliance-item .sh-comp-count { font-size: 1.6em; font-weight: 700; margin-top: 4px; }
.sh-compliance-item .sh-comp-label { font-size: 0.75em; color: var(--text-muted); }
.sh-comp-good .sh-comp-count { color: var(--success); }
.sh-comp-mid .sh-comp-count { color: var(--warning); }
.sh-comp-bad .sh-comp-count { color: var(--danger); }
.badge-score-green { background: #c6f6d5; color: #276749; padding: 4px 12px; border-radius: 12px; font-weight: 700; font-size: 0.9em; }
.badge-score-yellow { background: #fefcbf; color: #975a16; padding: 4px 12px; border-radius: 12px; font-weight: 700; font-size: 0.9em; }
.badge-score-orange { background: #feebc8; color: #c05621; padding: 4px 12px; border-radius: 12px; font-weight: 700; font-size: 0.9em; }
.badge-score-red { background: #fed7d7; color: #c53030; padding: 4px 12px; border-radius: 12px; font-weight: 700; font-size: 0.9em; }
.re-scope { display: flex; flex-wrap: wrap; gap: 8px; margin: 15px 0 20px; }
.re-scope .badge { background: var(--blue-bg); color: var(--primary-light); border: 1px solid var(--accent); font-size: 0.82em; padding: 5px 14px; border-radius: 20px; font-weight: 600; }
.re-scope .badge.active { background: var(--success-bg); color: var(--success); border-color: var(--success); }
.re-meta { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 30px; font-size: 0.9em; margin-bottom: 5px; }
.re-meta dt { color: var(--text-muted); font-weight: 600; }
.re-meta dd { color: var(--text); }
.re-security { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 12px; margin-bottom: 25px; }
.re-sec-card { background: var(--bg); border: 1px solid var(--border); border-radius: 10px; padding: 16px; text-align: center; border-top: 3px solid var(--border); }
.re-sec-card.good { border-top-color: var(--success); }
.re-sec-card.warn { border-top-color: var(--warning); }
.re-sec-card.bad { border-top-color: var(--danger); }
.re-sec-val { font-size: 1.8em; font-weight: 700; }
.re-sec-card.good .re-sec-val { color: var(--success); }
.re-sec-card.warn .re-sec-val { color: var(--warning); }
.re-sec-card.bad .re-sec-val { color: var(--danger); }
.re-sec-lbl { font-size: 0.78em; color: var(--text-muted); margin-top: 4px; line-height: 1.3; }
.re-findings { margin: 20px 0; }
.re-finding { display: flex; align-items: flex-start; gap: 12px; padding: 12px 16px; margin-bottom: 8px; border-radius: 8px; background: var(--bg); border: 1px solid var(--border); }
.re-finding-sev { flex-shrink: 0; padding: 3px 10px; border-radius: 12px; font-size: 0.75em; font-weight: 700; text-transform: uppercase; white-space: nowrap; }
.re-finding-sev.critico { background: #fed7d7; color: #c53030; }
.re-finding-sev.alto { background: #feebc8; color: #c05621; }
.re-finding-sev.medio { background: #fefcbf; color: #975a16; }
.re-finding-sev.bajo { background: #bee3f8; color: #2a4365; }
.re-finding-txt { font-size: 0.9em; line-height: 1.5; }
.re-exposure { text-align: center; padding: 25px; border-radius: 10px; margin: 20px 0; border: 2px solid; }
.re-exposure.alta { background: var(--danger-bg); border-color: var(--danger); }
.re-exposure.media { background: var(--warning-bg); border-color: var(--warning); }
.re-exposure.baja { background: var(--success-bg); border-color: var(--success); }
.re-exposure-level { font-size: 2em; font-weight: 800; letter-spacing: 3px; margin-bottom: 8px; }
.re-exposure.alta .re-exposure-level { color: var(--danger); }
.re-exposure.media .re-exposure-level { color: var(--warning); }
.re-exposure.baja .re-exposure-level { color: var(--success); }
.re-exposure-factors { font-size: 0.85em; color: var(--text-muted); text-align: left; max-width: 600px; margin: 12px auto 0; line-height: 1.6; }
.re-exposure-factors li { margin-bottom: 3px; }
.re-tools { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; }
.re-tools .badge { background: var(--primary); color: white; font-size: 0.8em; padding: 5px 14px; border-radius: 20px; }
@media print {
    .cover { min-height: auto; padding: 40px; page-break-after: always; }
    .section { page-break-inside: avoid; }
    body { font-size: 11pt; }
    .container { padding: 20px; }
}
</style>
</head>
<body>
HTMLEOF

# Portada
cat >> "$SALIDA" <<EOF
<div class="cover">
    <div class="shield">&#128737;</div>
    <h1>INFORME DE RECONOCIMIENTO OSINT</h1>
    <p class="subtitle">An&aacute;lisis de Seguridad y Exposici&oacute;n de Infraestructura</p>
    <div class="domain">${DOMINIO}</div>
    <p class="meta">Fecha de an&aacute;lisis: ${FECHA} &nbsp;|&nbsp; Generado: ${FECHA_HORA}</p>
</div>

<div class="container">
EOF

# ==========================================================
# RESUMEN EJECUTIVO
# ==========================================================


# --- Variables de alcance (badges) ---
B_WHOIS=""; B_SUBS=""; B_DNS=""; B_ASN=""; B_TECHS=""
B_SH=""; B_CERTS=""; B_ROBOTS=""; B_WAYBACK=""; B_KATANA=""
[ -f "$F_WHOIS" ] && [ -s "$F_WHOIS" ] && B_WHOIS='<span class="badge active">WHOIS</span>'
[ -f "$F_SUB" ] && [ -s "$F_SUB" ] && B_SUBS='<span class="badge active">Subdominios</span>'
[ -f "$F_DNS" ] && B_DNS='<span class="badge active">DNS</span>'
[ -f "$F_ASN" ] && B_ASN='<span class="badge active">ASN</span>'
[ -f "$F_HTTPX" ] && B_TECHS='<span class="badge active">Tecnolog&iacute;as</span>'
[ -f "$F_SH" ] && B_SH='<span class="badge active">Cabeceras HTTP</span>'
[ -f "$F_CERT" ] && B_CERTS='<span class="badge active">Certificados</span>'
[ -f "$F_ROBOTS" ] && B_ROBOTS='<span class="badge active">robots.txt</span>'
[ -f "$F_WAYBACK" ] && B_WAYBACK='<span class="badge active">Wayback Machine</span>'
[ -f "$F_KATFIL" ] && B_KATANA='<span class="badge active">Katana</span>'

# --- Hallazgos dinámicos (solo los que existen) ---
HALLAZGOS=""
N_HALL=0
MAX_HALL=8

if [ "${CERTS_VENCIDOS:-0}" -gt 0 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev critico\">Cr&iacute;tico</span><span class=\"re-finding-txt\">${CERTS_VENCIDOS} certificados SSL vencidos detectados, lo que expone a usuarios a advertencias de seguridad y posibles interrupciones de servicio.</span></div>"
fi
if [ "${ZERO_COUNT:-0}" -gt 0 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev critico\">Cr&iacute;tico</span><span class=\"re-finding-txt\">${ZERO_COUNT} de ${TOTAL_SH} hosts con cabeceras de seguridad cr&iacute;ticamente d&eacute;biles (score &le; 2/8), expuestos a clickjacking, XSS y downgrade de conexi&oacute;n.</span></div>"
fi
if [ "${SH_NO_HSTS:-0}" -gt 0 ] && [ "$TOTAL_SH" -gt 0 ] 2>/dev/null; then
    HSTS_RATIO=$(awk "BEGIN {printf \"%d\", (${SH_NO_HSTS}*100)/${TOTAL_SH}}")
    if [ "$HSTS_RATIO" -gt 50 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
        N_HALL=$((N_HALL+1))
        HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev alto\">Alto</span><span class=\"re-finding-txt\">${SH_NO_HSTS} de ${TOTAL_SH} hosts (${HSTS_RATIO}%) no implementan HSTS, permitiendo ataques de downgrade a conexiones no cifradas.</span></div>"
    fi
fi
if [ "${K_C_ADMIN:-0}" -gt 0 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev alto\">Alto</span><span class=\"re-finding-txt\">${K_C_ADMIN} endpoints administrativos expuestos p&uacute;blicamente,requeririendo revisi&oacute;n de controles de acceso.</span></div>"
fi
if [ "${K_C_AUTH:-0}" -gt 3 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev medio\">Medio</span><span class=\"re-finding-txt\">${K_C_AUTH} endpoints de autenticaci&oacute;n identificados, incluyendo login, SSO y OAuth. Se recomienda verificar controles de acceso.</span></div>"
fi
if [ "${K_C_API:-0}" -gt 0 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev medio\">Medio</span><span class=\"re-finding-txt\">${K_C_API} APIs documentadas o expuestas. Se recomienda asegurar autenticaci&oacute;n y rate limiting.</span></div>"
fi
if [ "${CERTS_PROXIMOS:-0}" -gt 5 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev medio\">Medio</span><span class=\"re-finding-txt\">${CERTS_PROXIMOS} certificados SSL pr&oacute;ximos a vencer en 30 d&iacute;as,riesgo de interrupci&oacute;n de servicio.</span></div>"
fi
if [ "${WB_C_ADMIN:-0}" -gt 0 ] || [ "${WB_C_API:-0}" -gt 0 ]; then
    WB_INTERES=$((WB_C_ADMIN + WB_C_API))
    if [ "$WB_INTERES" -gt 0 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
        N_HALL=$((N_HALL+1))
        HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev bajo\">Bajo</span><span class=\"re-finding-txt\">Wayback Machine revela ${WB_INTERES} recursos hist&oacute;ricos de inter&eacute;s (administraci&oacute;n/APIs) que podr&iacute;an contener informaci&oacute;n sensible obsoleta.</span></div>"
    fi
fi
if [ "${TOTAL_SUBS:-0}" -gt 50 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev bajo\">Bajo</span><span class=\"re-finding-txt\">${TOTAL_SUBS} subdominios descubiertos,superficie de ataque amplia que requiere auditor&iacute;a peri&oacute;dica.</span></div>"
fi
if [ "${K_C_MON:-0}" -gt 0 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev bajo\">Bajo</span><span class=\"re-finding-txt\">${K_C_MON} servicios de monitoreo detectados. Se recomienda verificar que no sean p&uacute;blicamente accesibles.</span></div>"
fi
if [ "${K_C_VPN:-0}" -gt 0 ] && [ "$N_HALL" -lt "$MAX_HALL" ]; then
    N_HALL=$((N_HALL+1))
    HALLAZGOS="${HALLAZGOS}<div class=\"re-finding\"><span class=\"re-finding-sev bajo\">Bajo</span><span class=\"re-finding-txt\">${K_C_VPN} servicios de acceso remoto detectados. Se recomienda asegurar autenticaci&oacute;n fuerte.</span></div>"
fi

# --- Nivel de exposición ---
EXPO_SCORE=0
EXPO_FACTORS=""

if [ "${TOTAL_SUBS:-0}" -gt 100 ]; then
    EXPO_SCORE=$((EXPO_SCORE+3))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${TOTAL_SUBS} subdominios descubiertos.</li>"
elif [ "${TOTAL_SUBS:-0}" -gt 50 ]; then
    EXPO_SCORE=$((EXPO_SCORE+1))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${TOTAL_SUBS} subdominios descubiertos.</li>"
fi
if [ "${TOTAL_HTTP:-0}" -gt 30 ]; then
    EXPO_SCORE=$((EXPO_SCORE+1))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${TOTAL_HTTP} hosts activos.</li>"
fi
if [ "${ZERO_COUNT:-0}" -gt 0 ] && [ "${TOTAL_SH:-0}" -gt 0 ]; then
    if [ "$((ZERO_COUNT * 2))" -gt "$TOTAL_SH" ]; then
        EXPO_SCORE=$((EXPO_SCORE+3))
        EXPO_FACTORS="${EXPO_FACTORS}<li>${ZERO_COUNT} hosts con cabeceras d&eacute;biles.</li>"
    elif [ "$((ZERO_COUNT * 4))" -gt "$TOTAL_SH" ]; then
        EXPO_SCORE=$((EXPO_SCORE+1))
        EXPO_FACTORS="${EXPO_FACTORS}<li>${ZERO_COUNT} hosts con cabeceras d&eacute;biles.</li>"
    fi
fi
if [ "${CERTS_VENCIDOS:-0}" -gt 0 ]; then
    EXPO_SCORE=$((EXPO_SCORE+2))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${CERTS_VENCIDOS} certificados vencidos.</li>"
fi
if [ "${CERTS_PROXIMOS:-0}" -gt 5 ]; then
    EXPO_SCORE=$((EXPO_SCORE+1))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${CERTS_PROXIMOS} certificados pr&oacute;ximos a vencer.</li>"
fi
if [ "${K_C_ADMIN:-0}" -gt 0 ]; then
    EXPO_SCORE=$((EXPO_SCORE+2))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${K_C_ADMIN} endpoints administrativos expuestos.</li>"
fi
if [ "${K_C_AUTH:-0}" -gt 3 ]; then
    EXPO_SCORE=$((EXPO_SCORE+1))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${K_C_AUTH} endpoints de autenticaci&oacute;n.</li>"
fi
if [ "${K_C_API:-0}" -gt 0 ]; then
    EXPO_SCORE=$((EXPO_SCORE+1))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${K_C_API} APIs documentadas.</li>"
fi
if [ "${TOTAL_KATANA_FIL:-0}" -gt 0 ]; then
    EXPO_SCORE=$((EXPO_SCORE+1))
    EXPO_FACTORS="${EXPO_FACTORS}<li>${TOTAL_KATANA_FIL} endpoints relevantes detectados.</li>"
fi

if [ "$EXPO_SCORE" -ge 8 ]; then
    EXPO_NIVEL="ALTA"; EXPO_CLASS="alta"
elif [ "$EXPO_SCORE" -ge 4 ]; then
    EXPO_NIVEL="MEDIA"; EXPO_CLASS="media"
else
    EXPO_NIVEL="BAJA"; EXPO_CLASS="baja"
fi


# --- Generar HTML del Resumen Ejecutivo ---
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128202; Resumen Ejecutivo</div>
    <div class="section-body">
        <p style="margin-bottom:20px;line-height:1.7;">Se realiz&oacute; un reconocimiento pasivo (OSINT) sobre el dominio <strong>${DOMINIO}</strong>, recopilando informaci&oacute;n p&uacute;blica relacionada con infraestructura, servicios, tecnolog&iacute;as web, configuraciones de seguridad y recursos hist&oacute;ricos accesibles. El objetivo fue caracterizar la superficie de exposici&oacute;n del dominio sin realizar interacci&oacute;n intrusiva con los sistemas analizados.</p>

        <h3 style="margin:20px 0 12px;color:var(--primary);font-size:1.05em;border-bottom:2px solid var(--accent);padding-bottom:6px;">&#128205; Alcance del Reconocimiento</h3>
        <div style="display:flex;justify-content:space-between;align-items:flex-start;flex-wrap:wrap;gap:20px;">
            <dl class="re-meta" style="margin:0;">
                <dt>Dominio objetivo</dt><dd class="mono">${DOMINIO}</dd>
                <dt>Tipo de reconocimiento</dt><dd>OSINT Pasivo</dt>
                <dt>Fecha de ejecuci&oacute;n</dt><dd>${FECHA}</dd>
                <dt>Estado del an&aacute;lisis</dt><dd><span class="badge badge-green">Finalizado</span></dd>
            </dl>
            <div>
                <dt style="color:var(--text-muted);font-weight:600;font-size:0.9em;margin-bottom:6px;">Informaci&oacute;n recopilada</dt>
                <div class="re-scope">
                    ${B_WHOIS}${B_SUBS}${B_DNS}${B_ASN}${B_TECHS}${B_SH}${B_CERTS}${B_ROBOTS}${B_WAYBACK}${B_KATANA}
                </div>
            </div>
        </div>

        <h3 style="margin:25px 0 12px;color:var(--primary);font-size:1.05em;border-bottom:2px solid var(--accent);padding-bottom:6px;">&#128200; M&eacute;tricas Generales</h3>
        <div class="stats-grid">
            <div class="stat-card"><div class="stat-value">${TOTAL_SUBS}</div><div class="stat-label">Subdominios descubiertos</div></div>
            <div class="stat-card"><div class="stat-value">${TOTAL_HTTP}</div><div class="stat-label">Hosts activos</div></div>
            <div class="stat-card"><div class="stat-value">${ASN_COUNT:-0}</div><div class="stat-label">ASN identificados</div></div>
            <div class="stat-card"><div class="stat-value">${TOTAL_TECHS}</div><div class="stat-label">Tecnolog&iacute;as detectadas</div></div>
            <div class="stat-card"><div class="stat-value">${TOTAL_WAYBACK}</div><div class="stat-label">URLs hist&oacute;ricas</div></div>
            <div class="stat-card"><div class="stat-value">${TOTAL_KATANA_FIL}</div><div class="stat-label">Endpoints relevantes</div></div>
            <div class="stat-card"><div class="stat-value">${TOTAL_CERTS}</div><div class="stat-label">Certificados analizados</div></div>
            <div class="stat-card"><div class="stat-value">${ROBOTS_200:-0}</div><div class="stat-label">robots.txt encontrados</div></div>
        </div>
EOF

# --- Estado de Seguridad (6 tarjetas con colores dinámicos) ---
if [ "$TOTAL_SH" -gt 0 ] 2>/dev/null; then
    SH_CON_HSTS=$((TOTAL_SH - SH_NO_HSTS))
    HSTS_CLASS="bad"; [ "$SH_CON_HSTS" -gt 0 ] && HSTS_CLASS="warn"; [ "$((SH_CON_HSTS * 2))" -ge "$TOTAL_SH" ] && HSTS_CLASS="good"

    CSP_CLASS="bad"; [ "${SH_CSP:-0}" -gt 0 ] && CSP_CLASS="warn"; [ "${SH_CSP:-0}" -ge 3 ] && CSP_CLASS="good"

    WEAK_CLASS="good"; [ "${ZERO_COUNT:-0}" -gt 0 ] && WEAK_CLASS="warn"; [ "$((ZERO_COUNT * 2))" -ge "$TOTAL_SH" ] && WEAK_CLASS="bad"

    VENC_CLASS="good"; [ "${CERTS_VENCIDOS:-0}" -gt 0 ] && VENC_CLASS="bad"

    PROX_CLASS="good"; [ "${CERTS_PROXIMOS:-0}" -gt 0 ] && PROX_CLASS="warn"; [ "${CERTS_PROXIMOS:-0}" -gt 5 ] && PROX_CLASS="bad"

    cat >> "$SALIDA" <<EOF
        <h3 style="margin:25px 0 12px;color:var(--primary);font-size:1.05em;border-bottom:2px solid var(--accent);padding-bottom:6px;">&#128737; Estado de Seguridad</h3>
        <div class="re-security">
            <div class="re-sec-card ${HSTS_CLASS}"><div class="re-sec-val">${SH_CON_HSTS}/${TOTAL_SH}</div><div class="re-sec-lbl">Hosts con HSTS</div></div>
            <div class="re-sec-card ${CSP_CLASS}"><div class="re-sec-val">${SH_CSP:-0}/${TOTAL_SH}</div><div class="re-sec-lbl">Hosts con CSP</div></div>
            <div class="re-sec-card ${WEAK_CLASS}"><div class="re-sec-val">${ZERO_COUNT}</div><div class="re-sec-lbl">Cabeceras d&eacute;biles (&le;2/8)</div></div>
            <div class="re-sec-card ${VENC_CLASS}"><div class="re-sec-val">${CERTS_VENCIDOS}</div><div class="re-sec-lbl">Certificados vencidos</div></div>
            <div class="re-sec-card ${PROX_CLASS}"><div class="re-sec-val">${CERTS_PROXIMOS}</div><div class="re-sec-lbl">Certificados pr&oacute;ximos (&le;30d)</div></div>
            <div class="re-sec-card good"><div class="re-sec-val">${ROBOTS_SITEMAP:-0}</div><div class="re-sec-lbl">Sitemaps detectados</div></div>
        </div>
EOF
fi

# --- Principales Hallazgos ---
if [ -n "$HALLAZGOS" ]; then
cat >> "$SALIDA" <<EOF
        <h3 style="margin:25px 0 12px;color:var(--primary);font-size:1.05em;border-bottom:2px solid var(--accent);padding-bottom:6px;">&#9888; Principales Hallazgos</h3>
        <div class="re-findings">
            ${HALLAZGOS}
        </div>
EOF
fi

# --- Nivel de Exposición ---
cat >> "$SALIDA" <<EOF
        <h3 style="margin:25px 0 12px;color:var(--primary);font-size:1.05em;border-bottom:2px solid var(--accent);padding-bottom:6px;">&#128737; Nivel de Exposici&oacute;n</h3>
        <div class="re-exposure ${EXPO_CLASS}">
            <div class="re-exposure-level">NIVEL DE EXPOSICI&Oacute;N: ${EXPO_NIVEL}</div>
            <p style="font-size:0.9em;color:var(--text-muted);margin-bottom:5px;">Factores considerados:</p>
            <ul class="re-exposure-factors">${EXPO_FACTORS}</ul>
        </div>
EOF

# --- Herramientas utilizadas ---
cat >> "$SALIDA" <<EOF
        <h3 style="margin:25px 0 12px;color:var(--primary);font-size:1.05em;border-bottom:2px solid var(--accent);padding-bottom:6px;">&#128295; Herramientas Utilizadas</h3>
        <div class="re-tools">
            <span class="badge">whois</span>
            <span class="badge">subfinder</span>
            <span class="badge">assetfinder</span>
            <span class="badge">findomain</span>
            <span class="badge">amass</span>
            <span class="badge">crt.sh</span>
            <span class="badge">dnsx</span>
            <span class="badge">asn.sh</span>
            <span class="badge">httpx</span>
            <span class="badge">curl</span>
            <span class="badge">Wayback Machine CDX API</span>
            <span class="badge">katana</span>
        </div>
    </div>
</div>
EOF


# ==========================================================
# WHOIS
# ==========================================================

if [ -f "$F_WHOIS" ] && [ -s "$F_WHOIS" ]; then
    WHOIS_B64=$(base64 -w 0 "$F_WHOIS" 2>/dev/null || base64 "$F_WHOIS" 2>/dev/null | tr -d '\r\n')
cat >> "$SALIDA" <<EOFWHOIS
<div class="section">
    <div class="section-header">&#128100; WHOIS - Datos del Registrante<div class="section-tool">Herramienta utilizada: whois</div></div>
    <div class="section-body">
        <div id="whois-content"></div>
        <div id="whois-raw" style="display:none" data-b64="${WHOIS_B64}"></div>
    </div>
</div>
EOFWHOIS

cat >> "$SALIDA" <<'EOFJS'
<script>
(function(){
var el=document.getElementById('whois-raw');
if(!el) return;
var b64=el.getAttribute('data-b64');
var text=decodeURIComponent(escape(atob(b64)));
var lines=text.split('\n');

function esc(s){ var d=document.createElement('div'); d.appendChild(document.createTextNode(s)); return d.innerHTML; }
function isSep(l){ return /^[\s=]+$/.test(l) && l.replace(/\s/g,'').length > 0; }

var sections=[];
var i=0;

while(i<lines.length && !isSep(lines[i])) i++;
if(i<lines.length) i++;
while(i<lines.length && !isSep(lines[i])) i++;
if(i<lines.length) i++;

while(i<lines.length){
    if(lines[i].trim()==='') { i++; continue; }
    if(/^Dominio consultado/i.test(lines[i].trim())) { i++; break; }
    break;
}

while(i<lines.length){
    var line=lines[i];
    if(isSep(line)){
        i++;
        var secName='';
        while(i<lines.length && lines[i].trim()==='') i++;
        if(i<lines.length && !isSep(lines[i])){
            secName=lines[i].trim();
            i++;
            while(i<lines.length && isSep(lines[i])) i++;
        }
        var fields=[];
        while(i<lines.length){
            if(isSep(lines[i])) break;
            if(lines[i].trim()==='') { i++; continue; }
            var m=lines[i].match(/^\s*(.+?)\s*:\s*(.*)$/);
            if(m){
                var fn=m[1].trim(), fv=m[2].trim();
                i++;
                while(i<lines.length && lines[i].trim()==='') i++;
                if(i<lines.length && !isSep(lines[i]) && !/^\s*.+\s*:\s*.+$/.test(lines[i]) && lines[i].trim()!==''){
                    fv+='\n'+lines[i].trim();
                    i++;
                }
                fields.push({n:fn, v:fv});
            } else { i++; }
        }
        if(secName) sections.push({name:secName, fields:fields});
    } else { i++; }
}

var out=document.getElementById('whois-content');
if(!out || sections.length===0) return;

var h='';
sections.forEach(function(sec,si){
    var isDNS=/servidor|dns|name.?server/i.test(sec.name);
    var isTitle=si===0;

    if(isTitle){
        h+='<table class="whois-table">';
        sec.fields.forEach(function(f){
            if(f.n && f.v) h+='<tr><td>'+esc(f.n)+'</td><td>'+esc(f.v)+'</td></tr>';
        });
        h+='</table>';
        return;
    }

    if(isDNS){
        var ns=[], other=[];
        sec.fields.forEach(function(f){
            if(/^name\s*server$/i.test(f.n)) ns.push(f.v);
            else other.push(f);
        });
        if(ns.length>0){
            h+='<div class="whois-section-title">&#128279; '+esc(sec.name)+'</div>';
            h+='<div class="whois-ns-box"><ul class="whois-ns-list">';
            ns.forEach(function(n){ h+='<li>'+esc(n)+'</li>'; });
            h+='</ul></div>';
        }
        if(other.length>0){
            if(ns.length===0) h+='<div class="whois-section-title">&#128279; '+esc(sec.name)+'</div>';
            h+='<table class="whois-table">';
            other.forEach(function(f){
                if(f.n && f.v) h+='<tr><td>'+esc(f.n)+'</td><td>'+esc(f.v)+'</td></tr>';
            });
            h+='</table>';
        }
        return;
    }

    h+='<div class="whois-section-title">&#128100; '+esc(sec.name)+'</div>';
    h+='<table class="whois-table">';
    sec.fields.forEach(function(f){
        if(f.n && f.v){
            var vHtml=esc(f.v).replace(/\n/g,'<br>');
            h+='<tr><td>'+esc(f.n)+'</td><td>'+vHtml+'</td></tr>';
        }
    });
    h+='</table>';
});

out.innerHTML=h;
})();
</script>
EOFJS
fi

# ==========================================================
# SUBDOMINIOS (solo resumen)
# ==========================================================

if [ -f "$F_SUB" ] && [ -s "$F_SUB" ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128269; Subdominios<div class="section-tool">Herramientas utilizadas: subfinder, assetfinder, findomain, amass, crt.sh</div></div>
    <div class="section-body">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${TOTAL_SUBS}</div>
                <div class="stat-label">Subdominios &uacute;nicos descubiertos</div>
            </div>
        </div>
    </div>
</div>
EOF
fi


# ==========================================================
# ASN / IPs
# ==========================================================

if [ -n "$ASN_HTML" ] && [ "$ASN_COUNT" -gt 0 ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#127760; ASN y Propietario de IPs<div class="section-tool">Herramienta utilizada: asn.sh</div></div>
    <div class="section-body">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${ASN_COUNT}</div>
                <div class="stat-label">ASN encontrados</div>
            </div>
        </div>
        <div style="margin-top:20px;">
            ${ASN_HTML}
        </div>
    </div>
</div>
EOF
fi


# ==========================================================
# DNS - SUBDOMINIOS ACTIVOS
# ==========================================================

if [ -n "$DNS_TABLA" ] && [ "$TOTAL_DNS" -gt 0 ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128279; DNS Activos<div class="section-tool">Herramienta utilizada: dnsx</div></div>
    <div class="section-body">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${TOTAL_DNS}</div>
                <div class="stat-label">registros encontrados</div>
            </div>
        </div>
        <div style="margin-top:20px;">
            ${DNS_TABLA}
        </div>
    </div>
</div>
EOF
fi


# ==========================================================
# HTTPX / TECNOLOGIAS
# ==========================================================

if [ -n "$HTTPX_TABLA" ] && [ "$TOTAL_HTTP" -gt 0 ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#127760; Tecnolog&iacute;as Web Detectadas<div class="section-tool">Herramienta utilizada: httpx</div></div>
    <div class="section-body">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${TOTAL_HTTP}</div>
                <div class="stat-label">hosts activos analizados</div>
            </div>
        </div>
        <div style="margin-top:20px;">
            ${HTTPX_TABLA}
        </div>
    </div>
</div>
EOF
fi


# ==========================================================
# SECURITY HEADERS
# ==========================================================

if [ -n "$SH_TABLA" ] && [ "$TOTAL_SH" -gt 0 ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128737; Cabeceras de Seguridad HTTP<div class="section-tool">Herramienta utilizada: curl (an&aacute;lisis de cabeceras HTTP de seguridad)</div></div>
    <div class="section-body">
        ${SH_EXPLAIN_HTML}
        ${SH_RESUMEN}
        ${SH_COMPLIANCE_HTML}
        <div style="margin-top:20px;">
            ${SH_TABLA}
        </div>
    </div>
</div>
EOF
fi


# ==========================================================
# CERTIFICADOS SSL
# ==========================================================

if [ -n "$CERT_TABLA" ] && [ "$TOTAL_CERTS" -gt 0 ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128274; Certificados SSL/TLS<div class="section-tool">Herramienta utilizada: certificados.sh</div></div>
    <div class="section-body">
        ${CERT_TABLA}
    </div>
</div>
EOF
fi


# ==========================================================
# ROBOTS.TXT
# ==========================================================

if [ -f "$F_ROBOTS" ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128196; An&aacute;lisis de robots.txt<div class="section-tool">Herramienta utilizada: curl &nbsp;&bull;&nbsp; Archivo analizado: robots.txt.txt</div></div>
    <div class="section-body">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${ROBOTS_TOTAL}</div>
                <div class="stat-label">Hosts analizados</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${ROBOTS_200:-0}</div>
                <div class="stat-label">robots.txt encontrados (200)</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${ROBOTS_404:-0}</div>
                <div class="stat-label">Sin robots.txt (404)</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${ROBOTS_ERR:-0}</div>
                <div class="stat-label">Errores de conexi&oacute;n</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${ROBOTS_SITEMAP:-0}</div>
                <div class="stat-label">Con Sitemap</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${ROBOTS_DISALLOW:-0}</div>
                <div class="stat-label">Con Disallow</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${ROBOTS_FULLBLOCK:-0}</div>
                <div class="stat-label">Bloqueo completo</div>
            </div>
        </div>

        <h3 style="margin: 25px 0 15px; color: var(--primary); font-size: 1.1em;">&#9888; Hallazgos Relevantes</h3>
        <div class="findings">
            ${ROBOTS_HTML}
        </div>

        <h3 style="margin: 25px 0 15px; color: var(--primary); font-size: 1.1em;">&#128203; Tabla Resumen</h3>
        ${ROBOTS_TABLE}

        <h3 style="margin: 25px 0 15px; color: var(--primary); font-size: 1.1em;">&#128161; Conclusiones</h3>
        <div style="padding: 15px 20px; background: var(--bg); border-radius: 8px; border: 1px solid var(--border);">
            ${ROBOTS_CONCLUSIONES}
        </div>
    </div>
</div>
EOF
fi


# ==========================================================
# WAYBACK MACHINE
# ==========================================================

if [ -n "$WB_MIME_TABLA" ] && [ "$TOTAL_WAYBACK" -gt 0 ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128338; Wayback Machine - An&aacute;lisis Hist&oacute;rico<div class="section-tool">Herramienta utilizada: Wayback Machine (CDX API) &nbsp;&bull;&nbsp; Archivo analizado: wayback.txt</div></div>
    <div class="section-body">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${TOTAL_WAYBACK}</div>
                <div class="stat-label">URLs hist&oacute;ricas</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${TOTAL_WB_SUBS}</div>
                <div class="stat-label">Subdominios con historial</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${TOTAL_WB_MIMES}</div>
                <div class="stat-label">Tipos MIME</div>
            </div>
        </div>

        <h3 style="margin: 25px 0 15px; color: var(--primary); font-size: 1.1em;">&#128202; Distribuci&oacute;n por Tipo MIME</h3>
        ${WB_MIME_TABLA}

        <h3 style="margin: 25px 0 15px; color: var(--primary); font-size: 1.1em;">&#128200; Subdominios con Mayor Actividad Hist&oacute;rica</h3>
        ${WB_SUBS_TABLA}

        <h3 style="margin: 25px 0 15px; color: var(--primary); font-size: 1.1em;">&#128269; Categor&iacute;as Detectadas</h3>
        ${WB_CAT_TABLA}

        <h3 style="margin: 25px 0 15px; color: var(--primary); font-size: 1.1em;">&#128161; Conclusiones</h3>
        <div style="padding: 15px 20px; background: var(--bg); border-radius: 8px; border: 1px solid var(--border);">
            ${WB_CONCLUSIONES}
        </div>
    </div>
</div>
EOF
fi


# ==========================================================
# KATANA / ANÁLISIS DE SUPERFICIE DE ATAQUE
# ==========================================================

if [ -n "$KATFIL_HTML" ] && [ "$TOTAL_KATANA_FIL" -gt 0 ]; then
cat >> "$SALIDA" <<EOF
<div class="section">
    <div class="section-header">&#128270; URLs Relevantes - Katana<div class="section-tool">Herramienta utilizada: Katana &nbsp;&bull;&nbsp; Crawler pasivo utilizado para descubrir rutas y endpoints interesantes</div></div>
    <div class="section-body">
        ${KATFIL_HTML}
    </div>
</div>
EOF
fi


# ==========================================================
# CONCLUSIONES Y RECOMENDACIONES (dinámicas)
# ==========================================================

# Variables ya calculadas: ZERO_COUNT, K_C_*, WB_C_*

cat >> "$SALIDA" <<'EOF'
<div class="section">
    <div class="section-header">&#128161; Conclusiones y Recomendaciones</div>
    <div class="section-body">
        <div class="findings">
EOF

# --- Resumen ejecutivo ---
cat >> "$SALIDA" <<EOF
            <div class="finding-item info">
                <h4>&#128202; Resumen del An&aacute;lisis</h4>
                <p>Se analiz&oacute; el dominio <strong>${DOMINIO}</strong> identificando <strong>${TOTAL_SUBS}</strong> subdominios, de los cuales <strong>${TOTAL_HTTP}</strong> presentan servicios HTTP activos. Se detectaron <strong>${TOTAL_DNS}</strong> registros DNS, <strong>${ASN_COUNT}</strong> ASN, <strong>${TOTAL_TECHS}</strong> tecnolog&iacute;as web diferentes y <strong>${TOTAL_KATANA_FIL}</strong> endpoints relevantes.</p>
            </div>
EOF

# --- Cabeceras de seguridad débiles ---
if [ "${ZERO_COUNT:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item">
                <h4>&#9888; ${ZERO_COUNT} hosts con cabeceras de seguridad cr&iacute;ticamente d&eacute;biles (0-2/8)</h4>
                <p>La gran mayor&iacute;a de subdominios carecen de HSTS, Content-Security-Policy y otras protecciones b&aacute;sicas. Esto expone a ataques de clickjacking, XSS y downgrade de conexi&oacute;n.</p>
            </div>
EOF
fi

# --- HSTS ausente ---
if [ "${SH_NO_HSTS:-0}" -gt 0 ] && [ "$TOTAL_SH" -gt 0 ] 2>/dev/null; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item warning">
                <h4>&#9888; ${SH_NO_HSTS} de ${TOTAL_SH} hosts sin HSTS habilitado</h4>
                <p>La ausencia de HTTP Strict Transport Security permite ataques de downgrade a HTTP. Se recomienda implementar HSTS con Directives max-age de al menos 31536000 segundos en todos los subdominios.</p>
            </div>
EOF
fi

# --- Certificados próximos a vencer ---
if [ "${CERTS_PROXIMOS:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item warning">
                <h4>&#9888; ${CERTS_PROXIMOS} certificados SSL por vencer en 30 d&iacute;as o menos</h4>
                <p>Los certificados pr&oacute;imos a vencer pueden causar interrupciones de servicio y advertencias de seguridad a los usuarios. Se recomienda renovar autom&aacute;ticamente con certbot o similar.</p>
            </div>
EOF
fi

# --- Subdominios ---
if [ "${TOTAL_SUBS:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item info">
                <h4>&#128269; ${TOTAL_SUBS} subdominios descubiertos en total</h4>
                <p>Un superficie de ataque amplia incrementa el riesgo. Se recomienda auditar peri&oacute;dicamente subdominios activos y desactivar los obsoletos.</p>
            </div>
EOF
fi

# --- Endpoints de autenticación ---
if [ "${K_C_AUTH:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item warning">
                <h4>&#128274; ${K_C_AUTH} endpoints de autenticaci&oacute;n detectados</h4>
                <p>Se localizaron rutas de login, SSO y OAuth. Se recomienda revisar controles de acceso, implementar MFA y verificar que no existan endpoints de autenticaci&oacute;n desprotegidos.</p>
            </div>
EOF
fi

# --- Endpoints administrativos ---
if [ "${K_C_ADMIN:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item">
                <h4>&#9888; ${K_C_ADMIN} endpoints administrativos expuestos</h4>
                <p>Se detectaron paneles de administraci&oacute;n y dashboards accesibles. Se recomienda restringir acceso por IP, implementar autenticaci&oacute;n robusta y evaluar si deben ser p&uacute;blicos.</p>
            </div>
EOF
fi

# --- APIs ---
if [ "${K_C_API:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item info">
                <h4>&#128268; ${K_C_API} APIs documentadas o detectadas</h4>
                <p>Se localizaron endpoints de API, Swagger y documentaci&oacute;n. Se recomienda asegurar que las APIs requieran autenticaci&oacute;n, implementar rate limiting y revisar que no expongan datos sensibles.</p>
            </div>
EOF
fi

# --- Monitoreo ---
if [ "${K_C_MON:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item info">
                <h4>&#128200; ${K_C_MON} servicios de monitoreo detectados</h4>
                <p>Se encontraron servicios como Grafana y Prometheus. Se recomienda verificar que no sean accesibles p&uacute;blicamente y que requieran autenticaci&oacute;n.</p>
            </div>
EOF
fi

# --- VPN / Acceso remoto ---
if [ "${K_C_VPN:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item warning">
                <h4>&#128272; ${K_C_VPN} servicios de acceso remoto detectados</h4>
                <p>Se identificaron endpoints VPN y de acceso remoto. Se recomienda asegurar que utilicen autenticaci&oacute;n fuerte y que no est&eacute;n expuestos a Internet sin control de acceso.</p>
            </div>
EOF
fi

# --- Configuración ---
if [ "${K_C_CONFIG:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item info">
                <h4>&#9881; ${K_C_CONFIG} endpoints de configuraci&oacute;n detectados</h4>
                <p>Se localizaron rutas de configuraci&oacute;n y archivos .well-known. Se recomienda revisar que no expongan informaci&oacute;n sensible del sistema.</p>
            </div>
EOF
fi

# --- Wayback: recursos históricos ---
if [ "${WB_C_BACKUP:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item">
                <h4>&#128451; ${WB_C_BACKUP} archivos hist&oacute;ricos de respaldo en Wayback Machine</h4>
                <p>Se encontraron archivos como .sql, .bak o .zip archivados. Se recomienda revisar y eliminar contenido obsoleto que pueda contener informaci&oacute;n sensible.</p>
            </div>
EOF
fi

# --- Wayback: recursos admin/API ---
if [ "${WB_C_ADMIN:-0}" -gt 0 ] || [ "${WB_C_API:-0}" -gt 0 ]; then
    WB_ADMIN_API=$((WB_C_ADMIN + WB_C_API))
    cat >> "$SALIDA" <<EOF
            <div class="finding-item info">
                <h4>&#128338; ${WB_ADMIN_API} recursos hist&oacute;ricos de inter&eacute;s en Wayback Machine</h4>
                <p>Se identificaron URLs hist&oacute;ricas relacionadas con administraci&oacute;n y APIs. Se recomienda revisar que las versiones antiguas no expongan credenciales o datos sensibles.</p>
            </div>
EOF
fi

# --- Wayback: contenido documentado ---
if [ "${WB_C_DOCS:-0}" -gt 0 ]; then
    cat >> "$SALIDA" <<EOF
            <div class="finding-item info">
                <h4>&#128214; ${WB_C_DOCS} documentos p&uacute;blicos en Wayback Machine</h4>
                <p>Se localizaron documentos (PDF, DOC, XLS) archivados hist&oacute;ricamente. Se recomienda revisar que no contengan informaci&oacute;n confidencial.</p>
            </div>
EOF
fi

# --- Recomendaciones dinámicas ---
HAY_RECOMENDACIONES=0
cat >> "$SALIDA" <<'EOF'
            <div class="finding-item info">
                <h4>&#128161; Recomendaciones Espec&iacute;ficas</h4>
EOF

if [ "${SH_NO_HSTS:-0}" -gt 0 ] && [ "$TOTAL_SH" -gt 0 ] 2>/dev/null; then
    echo "                <p><strong>&bull;</strong> Implementar HSTS en los ${SH_NO_HSTS} subdominios que actualmente carecen de esta protecci&oacute;n.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${K_C_AUTH:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Revisar controles de acceso en los ${K_C_AUTH} endpoints de autenticaci&oacute;n identificados.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${K_C_ADMIN:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Restringir acceso a los ${K_C_ADMIN} paneles administrativos expuestos.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${K_C_API:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Auditar las ${K_C_API} APIs detectadas para asegurar autenticaci&oacute;n y rate limiting.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${CERTS_PROXIMOS:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Renovar los ${CERTS_PROXIMOS} certificados SSL pr&oacute;ximos a vencer.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${K_C_MON:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Verificar que los ${K_C_MON} servicios de monitoreo no sean p&uacute;blicamente accesibles.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${K_C_VPN:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Asegurar los ${K_C_VPN} servicios de acceso remoto con autenticaci&oacute;n fuerte.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${K_C_CONFIG:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Revisar los ${K_C_CONFIG} endpoints de configuraci&oacute;n para evitar filtraciones.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${WB_C_BACKUP:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Eliminar o restringir los ${WB_C_BACKUP} archivos hist&oacute;ricos de respaldo encontrados.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${WB_C_ADMIN:-0}" -gt 0 ] || [ "${WB_C_API:-0}" -gt 0 ]; then
    echo "                <p><strong>&bull;</strong> Revisar recursos hist&oacute;ricos de administraci&oacute;n y APIs en Wayback Machine.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi
if [ "${TOTAL_SUBS:-0}" -gt 50 ]; then
    echo "                <p><strong>&bull;</strong> Auditar subdominios obsoletos: se detectaron ${TOTAL_SUBS} subdominios, superficie de ataque amplia.</p>" >> "$SALIDA"
    HAY_RECOMENDACIONES=1
fi

if [ "$HAY_RECOMENDACIONES" -eq 0 ]; then
    echo "                <p>No se encontraron hallazgos cr&iacute;ticos que requieran acci&oacute;n inmediata.</p>" >> "$SALIDA"
fi

cat >> "$SALIDA" <<'EOF'
            </div>
        </div>
    </div>
</div>
EOF


# Footer
cat >> "$SALIDA" <<EOF
<div class="footer">
    <p>Reporte generado autom&aacute;ticamente por <strong>OSINT Pipeline</strong> &mdash; ${FECHA_HORA}</p>
    <p>Dominio: ${DOMINIO} &nbsp;|&nbsp; Subdominios: ${TOTAL_SUBS} &nbsp;|&nbsp; Hosts HTTP: ${TOTAL_HTTP} &nbsp;|&nbsp; URLs: ${TOTAL_KATANA_FIL}</p>
</div>
</div>
</body>
</html>
EOF

echo
echo "[+] Reporte generado:"
echo "    $SALIDA"
echo
echo "[+] Metricas:"
echo "    Subdominios: $TOTAL_SUBS"
echo "    IPs unicas: $TOTAL_IPS"
echo "    Hosts HTTP: $TOTAL_HTTP"
echo "    Score seguridad promedio: ${SCORE_PROM}/8"
echo "    Certificados por vencer: $CERTS_PROXIMOS"
