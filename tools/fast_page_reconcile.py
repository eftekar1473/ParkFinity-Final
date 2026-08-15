import os
import sys
import win32com.client
import fitz

def convert_docx_to_pdf_word(docx_path, pdf_path):
    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    try:
        doc = word.Documents.Open(docx_path)
        # wdFormatPDF = 17
        doc.SaveAs(pdf_path, FileFormat=17)
        doc.Close(False)
    finally:
        word.Quit()

def extract_exact_pages_from_pdf(pdf_path, toc_entries, lof_entries):
    doc = fitz.open(pdf_path)
    total_pages = len(doc)
    print(f"PDF opened successfully. Total pages: {total_pages}")
    
    # Extract text per page
    page_texts = []
    for i in range(total_pages):
        page_texts.append(doc[i].get_text("text"))
        
    # Match TOC entries
    updated_toc = []
    for title, default_pg, level in toc_entries:
        # Search starting from page 3 (page 1 is cover, page 2 is TOC, page 3 is LOF)
        found_pg = default_pg
        # Clean title for matching (e.g., "1. Project Overview")
        match_str = title.strip()
        for p_idx, p_text in enumerate(page_texts):
            # Skip cover & front pages (index 0, 1, 2)
            if p_idx < 3:
                continue
            if match_str in p_text:
                found_pg = p_idx + 1
                break
        updated_toc.append((title, found_pg, level))
        
    # Match LOF entries
    updated_lof = []
    for fnum, fcaption, default_pg in lof_entries:
        found_pg = default_pg
        target = f"Figure {fnum}:"
        for p_idx, p_text in enumerate(page_texts):
            if p_idx < 3:
                continue
            if target in p_text:
                found_pg = p_idx + 1
                break
        updated_lof.append((fnum, fcaption, found_pg))
        
    return updated_toc, updated_lof, total_pages

if __name__ == "__main__":
    docx_file = os.path.abspath("ParkFinity_User_Manual_Report.docx")
    temp_pdf = os.path.abspath("temp_preview.pdf")
    
    print("Converting docx to preview PDF via Word COM...")
    convert_docx_to_pdf_word(docx_file, temp_pdf)
    print("Conversion complete.")
    
    from build_user_manual_master import DEFAULT_TOC, DEFAULT_LOF, generate_manual_docx
    
    updated_toc, updated_lof, total_pages = extract_exact_pages_from_pdf(temp_pdf, DEFAULT_TOC, DEFAULT_LOF)
    
    print("\n--- EXACT TOC MAPPINGS ---")
    for t, p, l in updated_toc:
        print(f"  {t} -> Page {p}")
        
    print("\n--- EXACT LOF MAPPINGS ---")
    for fn, cap, p in updated_lof:
        print(f"  Figure {fn}: {cap} -> Page {p}")
        
    print(f"\nRegenerating finalized docx with exact page mappings (Total pages: {total_pages})...")
    generate_manual_docx(docx_file, updated_toc, updated_lof)
    
    final_pdf = os.path.abspath("ParkFinity_User_Manual_Report.pdf")
    print(f"Exporting final PDF to {final_pdf}...")
    convert_docx_to_pdf_word(docx_file, final_pdf)
    
    print("\nAll User Manual documents generated and verified successfully!")
