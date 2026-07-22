$documentos = Get-ChildItem -Path . -Include *.md, *.qmd -Recurse -File
$enlacesRotos = 0

Write-Host "Buscando enlaces rotos..." -ForegroundColor Cyan

foreach ($doc in $documentos) {
    # Leer el documento entero
    $contenido = Get-Content -Path $doc.FullName -Raw
    
    # Buscar el patrón típico de imagen en Markdown: ![alt](ruta)
    $coincidencias = [regex]::Matches($contenido, '\!\[.*?\]\((.*?)\)')
    
    foreach ($match in $coincidencias) {
        $rutaImagen = $match.Groups[1].Value
        
        # Ignorar enlaces web externos (http/https)
        if ($rutaImagen -match "^http") { continue }
        
        # Descodificar el %20 a un espacio normal para comprobar en Windows
        $rutaLocal = $rutaImagen -replace "%20", " "
        
        # Comprobar si el archivo físico existe
        if (-not (Test-Path -Path $rutaLocal)) {
            Write-Host "Enlace roto en $($doc.Name): $rutaImagen" -ForegroundColor Red
            $enlacesRotos++
        }
    }
}

if ($enlacesRotos -eq 0) {
    Write-Host "¡Genial! No hay ningún enlace roto." -ForegroundColor Green
} else {
    Write-Host "Se encontraron $enlacesRotos enlaces rotos." -ForegroundColor Yellow
}