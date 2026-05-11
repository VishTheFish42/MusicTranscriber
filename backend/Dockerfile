FROM python:3.11-slim

# System deps: ffmpeg for audio conversion, LilyPond for PDF export
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    lilypond \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download the Basic Pitch model weights at build time so cold starts are fast
RUN python -c "from basic_pitch import ICASSP_2022_MODEL_PATH; print(ICASSP_2022_MODEL_PATH)"

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
