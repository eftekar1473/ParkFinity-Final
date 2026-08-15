$docxPath = "D:\SPL_2\ParkFinity_User_Manual_Report.docx"
$pdfPath = "D:\SPL_2\ParkFinity_User_Manual_Report.pdf"

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = [Microsoft.Office.Interop.Word.WdAlertLevel]::wdAlertsNone
    $doc = $word.Documents.Open($docxPath, $false, $false)
    $doc.Repaginate()
    
    # Update all fields in document (including TOC, LOF, Page Numbers)
    $doc.Fields.Update()
    foreach ($toc in $doc.TablesOfContents) {
        $toc.Update()
    }
    foreach ($tof in $doc.TablesOfFigures) {
        $tof.Update()
    }
    
    $pages = $doc.ComputeStatistics([Microsoft.Office.Interop.Word.WdStatistic]::wdStatisticPages)
    Write-Host "Word Repaginated successfully. Total Pages: $pages"
    
    # Save as PDF (wdFormatPDF = 17)
    $doc.SaveAs([ref]$pdfPath, [ref]17)
    Write-Host "Exported PDF successfully to $pdfPath"
    
    # Save updated docx
    $doc.Save()
    Write-Host "Saved updated docx."
    
    $doc.Close([ref]$false)
    $word.Quit([ref]$false)
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    Write-Host "Done!"
} catch {
    Write-Host "Error occurred: " $_.Exception.Message
} finally {
    Stop-Process -Name WINWORD -Force -ErrorAction SilentlyContinue
}
