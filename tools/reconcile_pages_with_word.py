import os
import sys
import win32com.client
import pythoncom
import time

def get_page_numbers_via_word(docx_path):
    print(f"Opening Word to extract exact page numbers from {docx_path}...")
    pythoncom.CoInitialize()
    word = win32com.client.Dispatch("Word.Application")
    word.Visible = False
    doc = word.Documents.Open(docx_path)
    
    # Force full layout pagination
    doc.Repaginate()
    
    # We want page numbers for Headings and Figures
    # Let's iterate paragraphs
    para_pages = []
    print("Reading paragraphs...")
    for p in doc.Paragraphs:
        txt = p.Range.Text.strip()
        if not txt:
            continue
        try:
            # wdActiveEndPageNumber = 3
            page_num = p.Range.Information(3)
            para_pages.append((txt, page_num))
        except Exception as e:
            pass
            
    total_pages = doc.ComputeStatistics(2) # wdStatisticPages = 2
    print(f"Total pages computed by Word: {total_pages}")
    
    doc.Close(False)
    word.Quit()
    pythoncom.CoUninitialize()
    return para_pages, total_pages

if __name__ == "__main__":
    docx_file = os.path.abspath("ParkFinity_User_Manual_Report.docx")
    para_pages, total_pages = get_page_numbers_via_word(docx_file)
    print(f"Extracted {len(para_pages)} paragraphs.")
    
    # Let's print headings and figures found
    for txt, pg in para_pages:
        if any(txt.startswith(prefix) for prefix in ["1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9.", "10.", "11.", "12.", "Figure ", "Appendix", "Supervisor Approval", "SUPERVISOR APPROVAL"]):
            print(f"[{pg}] {txt[:80]}")
