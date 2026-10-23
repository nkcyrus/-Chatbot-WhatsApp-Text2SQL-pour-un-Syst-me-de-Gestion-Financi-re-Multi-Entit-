# ── Image de base ────────────────────────────────────────────
FROM python:3.11-slim

# ── Variables d'environnement ────────────────────────────────
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ── Répertoire de travail ────────────────────────────────────
WORKDIR /app

# ── Dépendances système minimales ───────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# ── Dépendances Python ───────────────────────────────────────
# On copie requirements.txt en premier pour profiter du cache Docker
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Code source ──────────────────────────────────────────────
COPY . .

# ── Dossier exports CSV (créé au démarrage si absent) ────────
RUN mkdir -p exports

# ── Port exposé ──────────────────────────────────────────────
EXPOSE 5000

# ── Commande de démarrage ────────────────────────────────────
CMD ["python", "main.py"]
