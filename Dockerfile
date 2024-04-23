FROM nvcr.io/nvidia/pytorch:23.08-py3

RUN pip install --upgrade pip && \
    pip install fastapi gunicorn uvicorn[standard] transformers accelerate

WORKDIR /app
COPY app /app

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:9000", "--workers", "1", "--timeout", "0", "webservice:app", "-k", "uvicorn.workers.UvicornWorker"]
