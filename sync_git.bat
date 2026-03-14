@echo off
echo Sincronizando con el repositorio...
git add .
git commit -m "Sincronizacion automatica"
git push origin main
echo.
echo Proceso completado.
pause