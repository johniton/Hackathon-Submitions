"""
Hustlr Resume Builder — OCR Service
Extract text from PDFs (digital + scanned) and images.
Uses pdfplumber for digital PDFs, pytesseract for scanned/images.
"""
import os
import tempfile


async def extract_from_pdf(file_bytes: bytes, filename: str = "upload.pdf") -> dict:
    """Extract text from PDF. Digital layer first, OCR fallback."""
    import pdfplumber

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as f:
        f.write(file_bytes)
        f.flush()
        tmp_path = f.name

    try:
        # Step 1: Try digital text extraction
        text = ""
        with pdfplumber.open(tmp_path) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text() or ""
                text += page_text + "\n"

        text = text.strip()

        # Step 2: Quality check — if digital text is short, try OCR
        if len(text) < 100:
            print("[OCR] Digital text too short, trying OCR...")
            text = await _ocr_pdf(tmp_path)

        return {"text": text, "source": "pdf", "pages": len(pdf.pages) if text else 0}
    finally:
        os.unlink(tmp_path)


async def extract_from_image(file_bytes: bytes, filename: str = "upload.png") -> dict:
    """Extract text from image using pytesseract."""
    from PIL import Image
    import pytesseract
    import io

    image = Image.open(io.BytesIO(file_bytes))
    # Pre-process: convert to grayscale
    image = image.convert("L")
    text = pytesseract.image_to_string(image, lang="eng")

    return {"text": text.strip(), "source": "image"}


async def _ocr_pdf(pdf_path: str) -> str:
    """OCR a PDF by rendering pages to images."""
    try:
        from pdf2image import convert_from_path
        import pytesseract

        images = convert_from_path(pdf_path, dpi=300)
        text_parts = []
        for img in images:
            img_gray = img.convert("L")
            page_text = pytesseract.image_to_string(img_gray, lang="eng")
            text_parts.append(page_text)

        return "\n".join(text_parts).strip()
    except ImportError:
        print("[OCR] pdf2image not installed, skipping OCR fallback")
        return ""
    except Exception as e:
        print(f"[OCR] OCR failed: {e}")
        return ""


async def extract_certificate_info(file_bytes: bytes, filename: str, ai_extract_fn=None) -> dict:
    """Extract certificate metadata using OCR + optional AI parsing."""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    if ext == "pdf":
        result = await extract_from_pdf(file_bytes, filename)
    elif ext in ("png", "jpg", "jpeg", "webp"):
        result = await extract_from_image(file_bytes, filename)
    else:
        return {"cert_name": filename, "issuer": "", "issue_date": "", "skills": [], "raw_text": ""}

    raw_text = result.get("text", "")

    # If AI extraction function is provided, use it to parse certificate
    if ai_extract_fn and raw_text:
        try:
            parsed = await ai_extract_fn(raw_text)
            parsed["raw_text"] = raw_text[:500]
            return parsed
        except Exception as e:
            print(f"[OCR] AI cert parsing failed: {e}")

    # Basic fallback extraction
    return {
        "cert_name": filename.rsplit(".", 1)[0].replace("_", " ").replace("-", " ").title(),
        "issuer": "",
        "issue_date": "",
        "skills": [],
        "raw_text": raw_text[:500],
    }
