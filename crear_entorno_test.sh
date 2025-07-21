#!/bin/bash
#
# Script para crear un entorno de prueba para organizar_fotos.sh
#

# Salir si un comando falla
set -e

# Comprobar dependencias para crear el entorno
for cmd in exiftool ffmpeg; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: El comando '$cmd' no se encuentra. Es necesario para crear el entorno de prueba."
        exit 1
    fi
done


TEST_ROOT="entorno_de_prueba"

# Limpiar entorno anterior si existe
echo "Limpiando entorno de prueba anterior..."
rm -rf "$TEST_ROOT"

# Crear estructura de directorios
echo "Creando nueva estructura de directorios en '$TEST_ROOT'..."
SOURCE_DIR="$TEST_ROOT/origen"
DEST_DIR="$TEST_ROOT/destino"
ORIGINALS_DIR="$TEST_ROOT/videos_originales"

mkdir -p "$SOURCE_DIR"
mkdir -p "$DEST_DIR"
mkdir -p "$ORIGINALS_DIR"
mkdir -p "$SOURCE_DIR/Album Viaje a la Playa"

echo "Creando archivos de prueba..."

# --- CASOS DE USO ---

# 1. Imagen en la raíz con fecha EXIF (prioridad 1)
echo "  - Creando imagen con fecha EXIF..."
convert -size 10x10 xc:blue "$SOURCE_DIR/foto_con_exif.jpg"
exiftool -q -overwrite_original \
    -DateTimeOriginal="2023:05:15 10:00:00" \
    "$SOURCE_DIR/foto_con_exif.jpg"

# 2. Video en la raíz (para conversión y metadata de video)
echo "  - Creando video de prueba..."
ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=25 -pix_fmt yuv420p \
    -metadata creation_time="2024-02-20T11:00:00Z" \
    -y "$SOURCE_DIR/video_raiz.mp4" &> /dev/null

# 3. Imagen en la raíz con fecha en el nombre (prioridad 3)
echo "  - Creando imagen con fecha en el nombre..."
touch "$SOURCE_DIR/IMG_20221130_123456.jpeg"

# 4. Imagen en la raíz con fecha de modificación (último recurso)
echo "  - Creando imagen con fecha de modificación..."
touch -d "2021-08-01" "$SOURCE_DIR/foto_antigua.gif"

# 5. Archivos dentro de un subdirectorio (álbum)
echo "  - Creando archivos en un álbum..."
touch "$SOURCE_DIR/Album Viaje a la Playa/en_la_arena.jpg"
touch "$SOURCE_DIR/Album Viaje a la Playa/atardecer_01-07-2023.png"
ffmpeg -f lavfi -i smptebars=duration=2:size=320x240:rate=25 -pix_fmt yuv420p \
    -y "$SOURCE_DIR/Album Viaje a la Playa/olas.mov" &> /dev/null

# 6. Archivo Canon RAW en la raíz
touch "$SOURCE_DIR/canon_photo.cr2"

echo ""
echo "¡Entorno de prueba creado con éxito!"
echo "---------------------------------------"
echo "Directorio Origen:    $(realpath "$SOURCE_DIR")"
echo "Directorio Destino:   $(realpath "$DEST_DIR")"
echo "Directorio Originales: $(realpath "$ORIGINALS_DIR")"
echo ""
echo "Para ejecutar la prueba, usa el siguiente comando:"
echo "./organizar_fotos.sh \"$SOURCE_DIR\" \"$DEST_DIR\" \"$ORIGINALS_DIR\""
