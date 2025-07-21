chmod +x organizar_fotos.sh
chmod +x crear_entorno_test.sh

./crear_entorno_test.sh

./organizar_fotos.sh entorno_de_prueba/origen entorno_de_prueba/destino entorno_de_prueba/videos_originales

crontab -e

# Ejecutar el organizador de fotos y videos todos los días a las 3:00 AM
0 3 * * * /ruta/absoluta/a/organizar_fotos.sh /ruta/a/mi/carpeta/fotos_nuevas /ruta/a/mi/coleccion_final /ruta/a/mis/videos_originales > /var/log/organizador_fotos.log 2>&1

