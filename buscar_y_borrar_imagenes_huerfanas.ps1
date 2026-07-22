$imagenes = Get-ChildItem -Path "images" -File
$documentos = Get-ChildItem -Path . -Include *.md, *.qmd -Recurse -File

$borradas = 0

foreach ($img in $imagenes) {
    $enUso = $false
    
    $nombreOriginal = [regex]::Escape($img.Name)
    $nombreCodificado = [regex]::Escape(($img.Name -replace " ", "%20"))
    
    $patron = "$nombreOriginal|$nombreCodificado"

    foreach ($doc in $documentos) {
        if (Select-String -Path $doc.FullName -Pattern $patron -Quiet) {
            $enUso = $true
            break
        }
    }
    
    if (-not $enUso) {
        Write-Host "Borrando: $($img.Name)" -ForegroundColor Red
        # Aquí es donde ocurre la magia (y la destrucción)
        Remove-Item -Path $img.FullName -Force
        $borradas++
    }
}

if ($borradas -gt 0) {
    Write-Host "Limpieza completada. Se han borrado $borradas imágenes." -ForegroundColor Green
} else {
    Write-Host "¡Todo limpio! No se ha borrado nada." -ForegroundColor Green
}