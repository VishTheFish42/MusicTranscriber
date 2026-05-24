import traceback
from dataclasses import asdict
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from instruments import get_instrument
from pipeline.preprocess import prepare_audio
from pipeline.transcribe import run_basic_pitch
from pipeline.quantize import quantize
from pipeline.transpose import apply_transposition
from pipeline.assemble import build_musicxml, build_midi_b64, detect_key

router = APIRouter()


class TranscribeResponse(BaseModel):
    musicxml: str
    midi: str           # base64-encoded
    detected_tempo: float
    detected_time_sig: str
    detected_key: str
    duration_seconds: float
    note_events: list[dict]  # quantized notes; forwarded as-is to /regenerate


class RegenerateRequest(BaseModel):
    note_events: list[dict]
    instrument_id: str
    tempo: float
    time_sig: str
    key: str


class RegenerateResponse(BaseModel):
    musicxml: str
    midi: str


@router.post("/transcribe", response_model=TranscribeResponse)
async def transcribe(
    audio_file: UploadFile = File(...),
    instrument_id: str = Form(...),
    tempo_hint: int | None = Form(None),
    time_sig_hint: str | None = Form(None),
):
    try:
        instrument = get_instrument(instrument_id)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    audio_bytes = await audio_file.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=422, detail="Uploaded file is empty")

    try:
        tmp_path, samples, sr = prepare_audio(audio_bytes, audio_file.filename or "audio")
    except Exception:
        raise HTTPException(status_code=422, detail=f"[preprocess] {traceback.format_exc()}")

    duration_s = len(samples) / sr

    try:
        note_events = run_basic_pitch(tmp_path)
    except Exception:
        raise HTTPException(status_code=422, detail=f"[basic_pitch] {traceback.format_exc()}")
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    if not note_events:
        raise HTTPException(status_code=422, detail="No notes detected in audio")

    try:
        quantized, tempo, time_sig = quantize(note_events, samples, sr, tempo_hint, time_sig_hint)
        quantized = apply_transposition(quantized, instrument)
        key_name = detect_key(quantized)
        musicxml = build_musicxml(quantized, instrument, tempo, time_sig, key_name)
        midi_b64 = build_midi_b64(quantized, instrument, tempo)
    except Exception:
        raise HTTPException(status_code=422, detail=f"[assemble] {traceback.format_exc()}")

    return TranscribeResponse(
        musicxml=musicxml,
        midi=midi_b64,
        detected_tempo=tempo,
        detected_time_sig=time_sig,
        detected_key=key_name,
        duration_seconds=duration_s,
        note_events=[asdict(n) for n in quantized],
    )


@router.post("/regenerate", response_model=RegenerateResponse)
async def regenerate(req: RegenerateRequest):
    try:
        instrument = get_instrument(req.instrument_id)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    from pipeline.quantize import QuantizedNote
    quantized = [
        QuantizedNote(
            pitch=n["pitch"],
            onset_beat=n["onset_beat"],
            duration_name=n["duration_name"],
            duration_beats=n["duration_beats"],
            amplitude=n.get("amplitude", 0.8),
        )
        for n in req.note_events
    ]

    musicxml = build_musicxml(quantized, instrument, req.tempo, req.time_sig, req.key)
    midi_b64 = build_midi_b64(quantized, instrument, req.tempo)

    return RegenerateResponse(musicxml=musicxml, midi=midi_b64)
