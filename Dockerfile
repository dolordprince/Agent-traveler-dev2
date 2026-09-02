FROM python:3.11-slim

WORKDIR /app

# Install Node.js for skill executions
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 3456

ENV PORT=3456
ENV TARGET_BACKEND_URL=https://agent-traveler-dev2.onrender.com
ENV WORKSPACE_BASE=/tmp/claw_workspaces

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "3456"]
