#!/bin/bash
#
# Script para crear un entorno de prueba para organizar_fotos.sh
# (VERSIÓN CORREGIDA)
#

set -e

for cmd in exiftool ffmpeg convert; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: El comando '$cmd' no se encuentra. Es necesario para crear el entorno de prueba."
        exit 1
    fi
done

TEST_ROOT="entorno_de_prueba"
echo "Limpiando entorno de prueba anterior..."
rm -rf "$TEST_ROOT"

echo "Creando nueva estructura de directorios en '$TEST_ROOT'..."
SOURCE_DIR="$TEST_ROOT/origen"
DEST_DIR="$TEST_ROOT/destino"
ORIGINALS_DIR="$TEST_ROOT/videos_originales"

mkdir -p "$SOURCE_DIR" "$DEST_DIR" "$ORIGINALS_DIR"
mkdir -p "$SOURCE_DIR/Album Viaje a la Playa"

echo "Creando archivos de prueba..."

# --- CASOS DE USO BÁSICOS ---
# Imagen en la raíz con fecha EXIF
convert -size 10x10 xc:blue "$SOURCE_DIR/foto con exif.jpg"
exiftool -q -overwrite_original -DateTimeOriginal="2023:05:15 10:00:00" "$SOURCE_DIR/foto con exif.jpg"

# Video en la raíz para conversión
ffmpeg -f lavfi -i testsrc=duration=1:size=160x120:rate=10 -pix_fmt yuv420p \
    -metadata creation_time="2024-02-20T11:00:00Z" -y "$SOURCE_DIR/video raiz.mp4" &> /dev/null

# === INICIO DE LA CORRECCIÓN ===
# Archivos en álbum (creando un JPEG real en lugar de un archivo vacío)
convert -size 10x10 xc:green "$SOURCE_DIR/Album Viaje a la Playa/en la arena.jpg"
exiftool -q -overwrite_original -DateTimeOriginal="2023:07:01 12:00:00" "$SOURCE_DIR/Album Viaje a la Playa/en la arena.jpg"
# === FIN DE LA CORRECCIÓN ===


# --- NUEVOS CASOS DE PRUEBA ---

# 1. Video en origen que YA está convertido (sufijo _AV1)
echo "  - Creando video ya convertido en origen..."
ffmpeg -f lavfi -i testsrc=duration=1:size=160x120:rate=10 -pix_fmt yuv420p \
    -y "$SOURCE_DIR/Album Viaje a la Playa/video ya procesado_AV1.mp4" &> /dev/null

# 2. Video en origen cuyo destino convertido YA existe
echo "  - Creando un video original y su 'doble' ya convertido en destino..."
# Crear el subdirectorio de destino de antemano
mkdir -p "$DEST_DIR/2022/Vacaciones_Navidad"
# Crear el archivo "falso" convertido en el destino (aquí 'touch' es válido porque solo se comprueba su existencia)
touch "$DEST_DIR/2022/Vacaciones_Navidad/video_duplicado_AV1.mp4"

# Crear el álbum y el video original correspondiente en origen
mkdir -p "$SOURCE_DIR/Vacaciones Navidad"
ffmpeg -f lavfi -i testsrc=duration=1:size=160x120:rate=10 -pix_fmt yuv420p \
    -metadata creation_time="2022-12-25T18:00:00Z" \
    -y "$SOURCE_DIR/Vacaciones Navidad/video duplicado.mov" &> /dev/null

echo ""
echo "¡Entorno de prueba creado con éxito!"
echo "---------------------------------------"
echo "Para ejecutar la prueba, usa el siguiente comando:"
echo "./organizar_fotos.sh \"$SOURCE_DIR\" \"$DEST_DIR\" \"$ORIGINALS_DIR\""
echo ""
echo "RESULTADOS ESPERADOS:"
echo "1. En '$DEST_DIR/2023/Album_Viaje_a_la_Playa/', debe aparecer 'video_ya_procesado_AV1.mp4' (movido directamente)."
echo "2. En '$ORIGINALS_DIR/', debe aparecer 'video_duplicado.mov' (movido al detectar que el destino ya existía)."
echo "3. La conversión de 'video duplicado.mov' debe ser OMITIDA en los logs."
echo "4. El resto de archivos se organizarán como de costumbre (con espacios reemplazados por '_')."
