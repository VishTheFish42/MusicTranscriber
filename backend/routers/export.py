import subprocess
import tempfile
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

router = APIRouter()


class PDFRequest(BaseModel):
    musicxml: str
    paper_size: str = "a4"   # "a4" | "letter"


@router.post("/export/pdf")
async def export_pdf(req: PDFRequest):
    if req.paper_size not in ("a4", "letter"):
        raise HTTPException(status_code=422, detail="paper_size must be 'a4' or 'letter'")

    with tempfile.TemporaryDirectory() as tmp:
        xml_path = Path(tmp) / "score.xml"
        xml_path.write_text(req.musicxml, encoding="utf-8")

        ly_path = Path(tmp) / "score.ly"
        pdf_path = Path(tmp) / "score.pdf"

        # Convert MusicXML → LilyPond via music21, then render to PDF
        _musicxml_to_lilypond(str(xml_path), str(ly_path), req.paper_size)

        result = subprocess.run(
            ["lilypond", "--pdf", "-o", str(Path(tmp) / "score"), str(ly_path)],
            capture_output=True,
            timeout=60,
        )
        if result.returncode != 0:
            raise HTTPException(
                status_code=500,
                detail=f"LilyPond rendering failed: {result.stderr.decode()[:500]}",
            )

        if not pdf_path.exists():
            raise HTTPException(status_code=500, detail="PDF not produced by LilyPond")

        pdf_bytes = pdf_path.read_bytes()

    return Response(content=pdf_bytes, media_type="application/pdf")


def _musicxml_to_lilypond(xml_path: str, ly_path: str, paper_size: str) -> None:
    import music21.converter as m21conv
    score = m21conv.parse(xml_path)
    ly_content = score.write("lilypond")
    raw = Path(str(ly_content)).read_text(encoding="utf-8")

    # Inject paper size into the LilyPond header
    paper_block = f'\\paper {{\n  #(set-paper-size "{paper_size}")\n}}\n'
    Path(ly_path).write_text(paper_block + raw, encoding="utf-8")
