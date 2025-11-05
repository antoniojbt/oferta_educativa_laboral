# CSV to Access Database Conversion

## Overview

This directory contains synthetic datasets for testing the SIAP pipeline:
- `synthetic_dataset.csv` - Primera tabla de datos sintéticos
- `synthetic_dataset2.csv` - Segunda tabla de datos sintéticos

Estos archivos fueron generados con el script:
`oferta_educativa_laboral/pipeline/scripts/synthetic_from_summaries.R`

## Conversión a Access Database (.accdb)

### Para usuarios de Windows

Si tienes acceso a una máquina Windows con Microsoft Access o el Microsoft Access Database Engine instalado, puedes convertir los archivos CSV a formato .accdb usando el script:

```bash
python scripts/csv_to_accdb.py data/synthetic_dataset.csv data/synthetic_dataset2.csv -o data/synthetic_test_data.accdb
```

#### Requisitos para Windows:
1. Python 3.x con pyodbc: `pip install pyodbc`
2. Microsoft Access Database Engine:
   - Descarga de: https://www.microsoft.com/en-us/download/details.aspx?id=54920
   - Instala la versión apropiada (32-bit o 64-bit, debe coincidir con tu Python)

#### Proceso:
1. Copia los archivos CSV a tu máquina Windows
2. Instala los requisitos mencionados arriba
3. Ejecuta el script `csv_to_accdb.py`
4. El script creará un archivo .accdb con dos tablas:
   - `synthetic_dataset` (de synthetic_dataset.csv)
   - `synthetic_dataset2` (de synthetic_dataset2.csv)

### Para usuarios de Linux/Mac (alternativa de prueba)

En sistemas Linux/Mac donde no está disponible Microsoft Access, puedes usar el script alternativo que crea una base de datos SQLite para pruebas:

```bash
python scripts/csv_to_test_db.py data/synthetic_dataset.csv data/synthetic_dataset2.csv -o data/synthetic_test_data.db
```

**Nota**: Esta base de datos SQLite es sólo para pruebas preliminares. El pipeline completo requiere archivos .accdb reales.

## Estructura de las tablas

Ambos archivos CSV contienen las mismas columnas que las tablas reales del SIAP:

### Columnas numéricas:
- EDAD, ANT_DIAS, IMP_010, IMP_024, IMP_035, IMP_037, IMP_SDO, FALTASACUMULADAS

### Columnas de fecha:
- FECHAING, FECHAMOV, FECHAOCUP, FECHALIMOCU, FECHAINI, FECHAFIN, FECHAPROBJUB, FECHANOMINACION, FECHAPRIMERCONFZA

### Columnas categóricas:
- ADSCRIPCION, CATEGORIA, CLASIF_UNIDAD, COMSIN, CPTO180, DATOADIC_CATBASE, DELEGACION, DEPENDENCIA
- DESCRIPCION_SERVICIO, DESCRIP_CLASCATEG, DESCRIP_HORARIO, DESCRIP_LOCALIDAD, DESCRIP_TIPO_DE_PLAZA
- DESCRIP_TURNO, DescripcionTC, ESCOLARIDAD, GrupoTipoPlaza, JUBILA, MCABAJA, MCP, MY, NOMBREAR
- PLZAUT, PLZOCU, PLZSOB, PTO, RJP, SEXO, TipoConfianza, TipoMcaOcup, ULTIMACATEGBASE, VIGENCIAPTO

### Identificadores:
- CURP, RFC, NSS, MATRICULA

## Características de los datos sintéticos

Los datos sintéticos fueron generados para replicar:
- Distribuciones estadísticas de las variables reales (media, SD, cuartiles)
- Porcentajes de valores faltantes (NA) por columna
- Frecuencias relativas de categorías
- Formatos de identificadores (CURP, RFC, NSS, MATRICULA)
- Constraints de fechas (p.ej., FECHAFIN >= FECHAINI)

Los datos **NO** contienen información real de personas o instituciones.

## Uso en el pipeline

Una vez creado el archivo .accdb, colócalo en el directorio `data/` y el pipeline lo detectará automáticamente:

```bash
# Desde el directorio del pipeline
cd oferta_educativa_laboral/pipeline
python pipeline_oferta_laboral.py make full -v5
```

El pipeline:
1. Detectará automáticamente archivos .accdb en `../../data/`
2. Los convertirá a CSV
3. Ejecutará los scripts de limpieza y análisis:
   - `1b_accdb_tables_check.R`
   - `2_clean_dups_col_types.R`
   - `2b_clean_subset.R`
   - `3_explore.R`

## Problemas comunes

### En Windows:
- **"Driver not found"**: Instala Microsoft Access Database Engine
- **"Architecture mismatch"**: Asegúrate que Python y Access Engine sean ambos 32-bit o ambos 64-bit

### En Linux:
- **No se puede crear .accdb**: Correcto, usa csv_to_test_db.py para pruebas o ejecuta csv_to_accdb.py en Windows
- **mdb-tools no disponible**: El pipeline usa mdb-tools para leer .accdb en Linux. Si no está instalado: `sudo apt-get install mdb-tools`

## Contacto

Para preguntas sobre los datos sintéticos o la conversión, contacta a:
- @antoniojbt
- @lfrwaGitCoding  
- @DJAINEDELACRUZ
