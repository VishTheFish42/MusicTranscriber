"""
Converts any uploaded audio format to:
  - A temp WAV file at 22050 Hz mono (for Basic Pitch inference)
  - A float32 numpy array (for librosa tempo detection)

The caller is responsible for deleting the temp file after use.
"""

import subprocess
import tempfile
from pathlib import Path

import numpy as np


TARGET_SR = 22050
NOISE_GATE_DB = -50.0


def prepare_audio(data: bytes, source_filename: str = "audio") -> tuple[str, np.ndarray, int]:
    """
    Accept raw bytes of any ffmpeg-supported format.
    Returns (temp_wav_path, samples_float32, sample_rate).
    Caller must delete temp_wav_path when done.
    """
    suffix = Path(source_filename).suffix or ".audio"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp_in:
        tmp_in.write(data)
        tmp_in_path = tmp_in.name

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_out:
        tmp_out_path = tmp_out.name

    try:
        result = subprocess.run(
            [
                "ffmpeg", "-y",
                "-i", tmp_in_path,
                "-ac", "1",
                "-ar", str(TARGET_SR),
                "-sample_fmt", "f32le",
                "-f", "f32le",
                tmp_out_path,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            # Strip the version/config banner; the real error is in the last ~10 lines
            stderr_lines = result.stderr.strip().splitlines()
            tail = "\n".join(stderr_lines[-10:]) if len(stderr_lines) > 10 else result.stderr
            raise RuntimeError(
                f"ffmpeg decode failed (code {result.returncode}):\n{tail}"
            )
        samples = np.fromfile(tmp_out_path, dtype=np.float32)
    finally:
        Path(tmp_in_path).unlink(missing_ok=True)

    samples = _normalize(samples)
    samples = _noise_gate(samples)

    # Write the processed samples back so Basic Pitch reads the clean version
    samples.tofile(tmp_out_path)

    # Re-encode as proper WAV (Basic Pitch needs a valid WAV header)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_wav:
        tmp_wav_path = tmp_wav.name

    subprocess.run(
        [
            "ffmpeg", "-y",
            "-f", "f32le", "-ar", str(TARGET_SR), "-ac", "1",
            "-i", tmp_out_path,
            tmp_wav_path,
        ],
        check=True,
        capture_output=True,
    )
    Path(tmp_out_path).unlink(missing_ok=True)

    return tmp_wav_path, samples, TARGET_SR


def _normalize(samples: np.ndarray) -> np.ndarray:
    peak = np.abs(samples).max()
    if peak > 0:
        samples = samples / peak * 0.99
    return samples


def _noise_gate(samples: np.ndarray, frame_size: int = 2048) -> np.ndarray:
    threshold = 10 ** (NOISE_GATE_DB / 20)
    out = samples.copy()
    for i in range(0, len(samples), frame_size):
        frame = samples[i : i + frame_size]
        if np.sqrt(np.mean(frame**2)) < threshold:
            out[i : i + frame_size] = 0.0
    return out
