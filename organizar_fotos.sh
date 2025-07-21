#!/bin/bash
#
# Script para organizar una colección de fotos y videos.
#
# Uso: ./organizar_fotos.sh /ruta/a/origen /ruta/a/destino /ruta/para/videos_originales
#

# --- CONFIGURACIÓN Y VALIDACIÓN INICIAL ---

# Salir si un comando falla (útil para validaciones iniciales)
set -e

if [ "$#" -ne 3 ]; then
    echo "Error: Se requieren 3 argumentos."
    echo "Uso: $0 <directorio_origen> <directorio_destino> <directorio_videos_originales>"
    exit 1
fi

SOURCE_DIR=$(realpath "$1")
DEST_DIR=$(realpath "$2")
ORIGINALS_DIR=$(realpath "$3")

# Comprobación de dependencias
for cmd in exiftool ffmpeg mediainfo nproc; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: El comando '$cmd' no se encuentra. Por favor, instálalo."
        exit 1
    fi
done

# Validar que el directorio origen existe
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: El directorio de origen '$SOURCE_DIR' no existe."
    exit 1
fi

# Crear directorios de destino si no existen
mkdir -p "$DEST_DIR"
mkdir -p "$ORIGINALS_DIR"

# Volvemos a un comportamiento más permisivo para el bucle principal.
# Un fallo en un archivo no debe detener todo el proceso.
set +e

# --- BLOQUEO DE CONCURRENCIA ---

# Se usa flock para asegurar que solo una instancia del script se ejecute a la vez.
# El script intentará adquirir un bloqueo en el fichero /tmp/organizer.lock.
# Si no puede (porque ya está bloqueado), saldrá con un mensaje.
LOCK_FILE="/tmp/organizer.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "Otra instancia del script ya se está ejecutando." >&2; exit 1; }
# El bloqueo se liberará automáticamente cuando el script termine.


# --- DEFINICIÓN DE FUNCIONES ---

# Función para obtener la fecha de un archivo
# Devuelve la fecha en formato YYYY-MM-DD
get_file_date() {
    local file="$1"
    local date_str=""

    # 1. Intentar con metadatos EXIF (DateTimeOriginal o CreateDate)
    date_str=$(exiftool -q -p '$DateTimeOriginal' -d '%Y-%m-%d' "$file" 2>/dev/null)
    if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "$date_str"
        return
    fi
    date_str=$(exiftool -q -p '$CreateDate' -d '%Y-%m-%d' "$file" 2>/dev/null)
     if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "$date_str"
        return
    fi

    # 2. Intentar con metadatos de video (Encoded Date)
    date_str=$(mediainfo --Output="General;%Encoded_Date%" "$file" 2>/dev/null | sed 's/UTC //g' | cut -d' ' -f1)
     if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "$date_str"
        return
    fi

    # 3. Intentar con patrones de nombre de archivo
    local filename
    filename=$(basename "$file")
    # Patrón: YYYY-MM-DD, YYYY_MM_DD, YYYYMMDD
    if [[ "$filename" =~ ([0-9]{4})[-_]?([0-9]{2})[-_]?([0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}"
        return
    fi
    # Patrón: DD-MM-YYYY, DD_MM_YYYY, DDMMYYYY
    if [[ "$filename" =~ ([0-9]{2})[-_]?([0-9]{2})[-_]?([0-9]{4}) ]]; then
        echo "${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}"
        return
    fi

    # 4. Como último recurso, usar la fecha de modificación del archivo
    date -r "$file" "+%Y-%m-%d"
}


# --- PROCESAMIENTO PRINCIPAL ---

echo "Iniciando la organización de '$SOURCE_DIR'..."
echo "Destino: '$DEST_DIR'"
echo "Originales de video: '$ORIGINALS_DIR'"
echo "-------------------------------------------"

# Usamos find y un bucle while para procesar archivos, incluso con espacios en el nombre
find "$SOURCE_DIR" -type f | while IFS= read -r file; do
    
    # Identificar si es imagen o video por la extensión (insensible a mayúsculas/minúsculas)
    ext="${file##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    file_type=""
    case "$ext_lower" in
        jpg|jpeg|gif|png|heic|cr2|crw|nef|orf|raw|dng|arw)
            file_type="image"
            ;;
        mov|3gp|avi|mkv|mp4|mpg|mpeg|wmv|flv|webm|m4v)
            file_type="video"
            ;;
        *)
            echo "OMITIENDO: Archivo no reconocido '$file'"
            continue
            ;;
    esac

    # --- Determinar la fecha y la ruta de destino ---
    file_date=$(get_file_date "$file")
    if [ -z "$file_date" ]; then
        echo "ERROR: No se pudo determinar la fecha para '$file'. Omitiendo."
        continue
    fi
    
    year=$(echo "$file_date" | cut -d'-' -f1)
    month=$(echo "$file_date" | cut -d'-' -f2)

    dest_path=""
    file_dir=$(dirname "$file")
    
    # Punto 4 y 5: Lógica de Álbum vs Raíz
    if [ "$file_dir" == "$SOURCE_DIR" ]; then
        # Archivo en la raíz -> YYYY/MM
        dest_path="$DEST_DIR/$year/$month"
    else
        # Archivo en subdirectorio -> Nombre del álbum
        album_name=$(basename "$file_dir")
        dest_path="$DEST_DIR/$album_name"
    fi
    
    mkdir -p "$dest_path"

    # --- Procesar el archivo ---
    
    if [ "$file_type" == "image" ]; then
        echo "MOVIENDO IMAGEN: $file -> $dest_path/"
        mv -n "$file" "$dest_path/" # -n para no sobrescribir

    elif [ "$file_type" == "video" ]; then
        echo "PROCESANDO VIDEO: $file"

        # Punto 7: Directorio temporal para la conversión
        TMP_DIR=$(mktemp -d)
        # Asegurarse de que el directorio temporal se borre al salir o si hay un error
        trap 'rm -rf "$TMP_DIR"' RETURN

        base_name=$(basename "$file" ."$ext")
        output_file="$TMP_DIR/${base_name}_AV1.mp4"

        # Punto 6: Parámetros de FFmpeg
        num_threads=$(nproc)
        svt_params="keyint=10s:input-depth=8:tune=0:film-grain=0:fast-decode=1:rc=0:lp=${num_threads}"

        echo "  -> Convirtiendo a AV1 (esto puede tardar)..."
        if ffmpeg -i "$file" \
           -c:v libsvtav1 \
           -crf 38 \
           -preset 6 \
           -svtav1-params "$svt_params" \
           -c:a copy \
           -map_metadata 0 \
           -movflags +faststart \
           -y "$output_file" &> /dev/null; then # Redirigimos la salida para no llenar el log

            echo "  -> Conversión exitosa."
            
            # Mover el archivo convertido al destino final
            final_dest_file="$dest_path/$(basename "$output_file")"
            echo "  -> Moviendo convertido a: $final_dest_file"
            mv -n "$output_file" "$final_dest_file"

            # Mover el archivo original al directorio de originales
            echo "  -> Moviendo original a: $ORIGINALS_DIR/"
            mv -n "$file" "$ORIGINALS_DIR/"

        else
            echo "ERROR: Falló la conversión de '$file'. El original se dejará en su sitio."
        fi

        # Limpiar el trap para la siguiente iteración del bucle
        trap - RETURN
        rm -rf "$TMP_DIR"
    fi
done

echo "-------------------------------------------"
echo "Proceso de organización finalizado."
