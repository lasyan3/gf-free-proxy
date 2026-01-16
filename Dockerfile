FROM python:3.12-alpine3.21

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LISTEN_HOST=0.0.0.0 \
    LISTEN_PORT=8888

WORKDIR /app

# Dépendances Python (cache Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code applicatif
COPY main.py config.example.py ./

# User non-root
RUN adduser -D -s /sbin/nologin appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8888

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:${LISTEN_PORT}/health || exit 1

CMD python -m uvicorn main:app --host ${LISTEN_HOST} --port ${LISTEN_PORT}
