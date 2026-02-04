FROM python:3.10

WORKDIR /app

COPY requirements.txt requirements.txt

RUN python -m pip install --upgrade pip && python -m pip install -r requirements.txt

COPY . .

RUN useradd -m appuser && \
    chown -R appuser:appuser /app

USER appuser