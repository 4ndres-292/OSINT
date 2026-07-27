# OSINT Pipeline - Reconocimiento de Seguridad

Pipeline automatizado de reconocimiento OSINT para auditorías de seguridad. Ejecuta 11 herramientas en secuencia y genera un reporte HTML profesional para presentación académica.

## Uso Rápido

```bash
chmod +x osint.sh generar_reporte.sh
./osint.sh [dominio]
```

## Estructura del Proyecto

```
monografia/
├── osint.sh                        Orquestador principal (11 pasos)
├── generar_reporte.sh              Generador de reporte HTML
├── subdominios_nic.txt             Categorías NIC Bolivia (21 registros)
│
├── whois_bo.sh                     Consulta WHOIS a NIC Bolivia
├── datos_whois.sh                  Parsea HTML de NIC Bolivia a texto
├── todos_los_subdominios.sh        Descubre subdominios con 5 fuentes
├── dnsx.sh                         Resolución de registros DNS
├── asn.sh                          Mapeo IPs → ASN, organización
├── httpx.sh                        Detección de tecnologías web
├── security_headers.sh             Auditoría de cabeceras HTTP
├── certificados.sh                 Análisis de certificados SSL
├── robots.sh                       Búsqueda de robots.txt
├── wayback.sh                      Consulta de URLs históricas
├── katana.sh                       Crawling profundo + filtro integrado
│
└── resultados/
    └── [dominio]/
        ├── whois_[dominio].txt
        ├── subdominios_[dominio].txt
        ├── dns_[dominio].txt
        ├── asn_[dominio].txt
        ├── httpx_[dominio].txt
        ├── security_headers_[dominio].txt
        ├── certificados_[dominio].txt
        ├── robots_[dominio].txt
        ├── wayback_[dominio].txt
        ├── katana_[dominio].txt
        ├── katana_filtrado_[dominio].txt
        ├── reporte_[dominio].html
        └── errores.log
```

## Pipeline de Ejecución

| Paso | Script | Descripción | Archivo de salida |
|------|--------|-------------|-------------------|
| 1 | `whois_bo.sh` | WHOIS NIC Bolivia | `whois_[dominio].txt` |
| 2 | `todos_los_subdominios.sh` | Descubrimiento con 5 herramientas | `subdominios_[dominio].txt` |
| 3 | `dnsx.sh` | Registros DNS (A, AAAA, CNAME, MX, TXT, NS, SOA) | `dns_[dominio].txt` |
| 4 | `asn.sh` | IPs → ASN, organización, país | `asn_[dominio].txt` |
| 5 | `httpx.sh` | Tecnologías web, status code, título | `httpx_[dominio].txt` |
| 6 | `security_headers.sh` | Cabeceras de seguridad (score 0-8) | `security_headers_[dominio].txt` |
| 7 | `certificados.sh` | Certificados SSL/TLS | `certificados_[dominio].txt` |
| 8 | `robots.sh` | Archivos robots.txt | `robots_[dominio].txt` |
| 9 | `wayback.sh` | URLs históricas | `wayback_[dominio].txt` |
| 10 | `katana.sh` | Crawling + filtrado de URLs | `katana_[dominio].txt` + `katana_filtrado_[dominio].txt` |
| 11 | `generar_reporte.sh` | Reporte HTML profesional | `reporte_[dominio].html` |

## Dependencias

### Herramientas principales

| Categoría | Herramienta | Propósito |
|-----------|-------------|-----------|
| Subdominios | `subfinder`, `assetfinder`, `amass`, `findomain` | Enumeración de subdominios |
| DNS | `dnsx` | Resolución masiva de registros |
| Web | `httpx`, `katana` | Tecnologías y crawling |
| APIs | `curl` | crt.sh, Wayback, NIC Bolivia, ipinfo.io |
| Procesamiento | `jq`, `openssl`, `python3`, `whois` | JSON, certificados, WHOIS |

### Instalación de dependencias (Kali/Debian)

```bash
# Go tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest

# Assetfinder
go install github.com/tomnomnom/assetfinder@latest

# Findomain
wget https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux -O /usr/local/bin/findomain
chmod +x /usr/local/bin/findomain

# Otras dependencias
sudo apt install jq openssl whois python3
```

### Froma de uso independiente

Cada script se puede ejecutar de forma individual:

```bash
# WHOIS
./whois_bo.sh minedu.gob.bo

# Subdominios
./todos_los_subdominios.sh minedu.gob.bo

# DNS (requiere subdominios previos)
./dnsx.sh minedu.gob.bo resultados/minedu.gob.bo/subdominios_minedu.gob.bo.txt

# ASN (requiere DNS previo)
./asn.sh minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt

# HTTPX
./httpx.sh minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt

# Security Headers
./security_headers.sh minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt

# Certificados
./certificados.sh minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt

# Robots
./robots.sh minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt

# Wayback
./wayback.sh minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt

# Katana
./katana.sh minedu.gob.bo resultados/minedu.gob.bo/dns_minedu.gob.bo.txt

# Reporte HTML
./generar_reporte.sh minedu.gob.bo
```

## Generación del Reporte

El reporte HTML se genera automáticamente como paso 11 del pipeline, o de forma independiente:

```bash
./generar_reporte.sh minedu.gob.bo
```

### Contenido del reporte

- Portada con dominio y fecha
- Resumen ejecutivo con métricas clave
- WHOIS (datos del registrante)
- Subdominios (conteo y listado)
- DNS/ASN (registros y propietarios)
- Tecnologías web detectadas
- Cabeceras de seguridad (con score colorido)
- Certificados SSL (días restantes)
- Robots.txt
- Wayback Machine
- URLs filtradas (admin, api, login, etc.)
- Conclusiones y recomendaciones automáticas

### Formato

HTML autocontenido con CSS embebido. Se abre en cualquier navegador, se proyecta directamente, y se puede imprimir a PDF con Ctrl+P.

## Manejo de Errores

- Si un paso falla, se registra en `resultados/[dominio]/errores.log` y el pipeline continúa
- Los scripts verifican la existencia de archivos de entrada antes de ejecutarse
- Si falta una dependencia, el error se reporta sin detener el proceso

## Convención de Archivos

Todos los archivos de salida siguen el patrón `nombre_[dominio].txt` dentro de `resultados/[dominio]/`.

| Archivo | Contenido |
|---------|-----------|
| `whois_[dominio].txt` | Datos del registrante, fechas, DNS |
| `subdominios_[dominio].txt` | Lista de subdominios únicos |
| `dns_[dominio].txt` | Registros DNS resueltos |
| `asn_[dominio].txt` | IPs con ASN y organización |
| `httpx_[dominio].txt` | Hosts HTTP con tecnologías |
| `security_headers_[dominio].txt` | Score de cabeceras por host |
| `certificados_[dominio].txt` | Estado de certificados SSL |
| `robots_[dominio].txt` | Contenido de robots.txt |
| `wayback_[dominio].txt` | URLs históricas |
| `katana_[dominio].txt` | URLs descubiertas (crudo) |
| `katana_filtrado_[dominio].txt` | URLs relevantes (filtradas) |
| `reporte_[dominio].html` | Informe visual completo |
| `errores.log` | Registro de fallos del pipeline |

## Notas

- `subdominios_nic.txt` debe permanecer en la raíz del proyecto
- Los scripts resuelven sus rutas con `$(dirname "$0")` para funcionar desde cualquier directorio
- El filtro de Katana está integrado dentro de `katana.sh` (paso 10)
- El script `generar_reporte.sh` maneja archivos faltantes sin romperse
