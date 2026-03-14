@echo off
echo =======================================================
echo Sincronizando TODAS las ramas del repositorio remoto
echo =======================================================

echo 1. Descargando informacion de todas las ramas (fetch)...
git fetch --all

echo.
echo 2. Creando referencias locales para las ramas remotas...
rem Itera sobre todas las ramas remotas
for /f "tokens=*" %%r in ('git branch -r ^| findstr /v "\->"') do (
    rem Separa el remoto del nombre de la rama (ej. origin/rama -> rama)
    for /f "tokens=1* delims=/" %%a in ("%%r") do (
        rem %%b es el nombre de la rama
        if "%%b" neq "" (
            rem Intenta crear la rama local trackeando la remota
            rem Si ya existe, esto fallara silenciosamente y no pasa nada
            git branch --track "%%b" "%%r" >nul 2>&1
            if not errorlevel 1 echo [+] Rama '%%b' configurada.
        )
    )
)

echo.
echo 3. Estado actual de ramas:
git branch -vv

echo.
echo =======================================================
echo Proceso finalizado. 
echo Ahora tienes todas las ramas disponibles en tu PC.
echo Usa 'git checkout nombre-rama' para cambiar entre ellas.
echo =======================================================
pause