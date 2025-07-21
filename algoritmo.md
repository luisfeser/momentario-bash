# Script para organizar colección de fotos y videos

El script debe cumplir:
1. escrito en bash
2. tratará todos los archivos en directorios y subdirectorios que sean de tipo imagen o videos (las extensiones más habituales en los últimos 20 años: mov, 3pg, avi, mkv, mp4, jpg, jpeg, gif, fotos y videos de cámaras canon, y demás marcas conocidas)
3. se guardará en una variable la fecha de realización de la foto o video. Para ello usará un programa de acceso a los datos exif o del video y extraerá la fecha según estos criterios:
  1. Fecha del date time o date time original de los datos exif
  2. Fecha de creación del video si es un video
  3. fecha extraida del nombre del archivo según un patrón, como:
  patterns = [
        r"(\d{4})[-_]?(\d{2})[-_]?(\d{2})",  # YYYY-MM-DD, YYYYMMDD
        r"(\d{2})[-_]?(\d{2})[-_]?(\d{4})",  # DD-MM-YYYY, DDMMYYYY
    ]
  4. Por la fecha de creación del fichero
4. Si el archivo a tratar está en la raiz del directorio a procesar, entonces se creará en destino un directorio año y un subdirectorio mes (si no existe) y se moverá a dicho subdirectorio (2025/07/fichero.jpg)
5. Si el archivo está en un subdirectorio dentro del directorio raiz a procesar, entonces ese directorio se entiende que es un álbum y se creará esa misma carpeta en el directorio destino y se moverán los archivos a él.
6. Si el archivo es un video, además de lo anterior, primero se convertirá con ffmpeg al codec AV1 con las opciones:
  - codec libsvtav1
  - sonido: copy
  - copiar metadata: map_metadata: 0
  - crf de 38
  - preset de 6
  -svtav1-params --> format!("keyint=10s:input-depth=8:tune=0:film-grain=0:fast-decode=1:rc=0:lp={}", num_threads))
  - num_threads obtenidas del entorno de ejecución
  - movflags
  - +faststart
  - al archivo destino, al final del nomnbre y antes de la extensión se le añadirá el sufijo "_AV1" y siempre será con formato mp4 (si el original es otro tipo de fichero se guardará como mp4)
  - el archivo convertido se moverá al directorio correspondiente según los puntos 4 y 5
  - el archivo original se moverá al directorio "videos_originales" que será informado como parámetro en la ejecución del script
7. Como puede haber un imprevisto en la conversión del fichero, se utilizará un directorio temporal de tal modo que si se interrumpe la conversión el archivo original seguirá en su sitio y cuando se vuelva a ejecutar el script se podrá volver a tratar.
8. El script se ejecutará automáticamente con cron y además podrá ejecutarse con distintos argumentos (distintas carpetas origen). Hay que hacer que el script solo pueda ejecutarse una vez al mismo tiempo, si cuando llega la hora de ejecutarse ya hay una instancia del script corriendo, con los mismos u otros parámetros, entonces no se ejecutará y se esperará a la próxima ejecución del cron.
9. Haz otro "subscript" para poder testear todo lo anterior creando automáticamente todos los ficheros que sean precisos para cumplir todos los casos de uso.


