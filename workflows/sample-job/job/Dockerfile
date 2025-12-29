# Dockerfile for Sample Ingest Job
# Demonstrates orchestrator-agnostic containerized job

FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy job code
COPY ingest.py .

# Create non-root user
RUN useradd -m -u 1000 jobuser && \
    chown -R jobuser:jobuser /app

# Switch to non-root user
USER jobuser

# Set environment variables
ENV LOG_LEVEL=INFO

# Run job
# Arguments will be provided by orchestrator
ENTRYPOINT ["python", "ingest.py"]
