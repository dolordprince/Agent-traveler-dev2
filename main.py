import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Traveler Dev Backend")

# Enable full CORS for Hugging Face Spaces and WebContainer requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class GenerateRequest(BaseModel):
    prompt: str

@app.get("/health")
def health_check():
    return {"status": "ok", "groq_configured": bool(os.getenv("GROQ_API_KEY"))}

@app.post("/api/generate")
def generate_project(req: GenerateRequest):
    # Generates a valid WebContainer filesystem tree
    return {
        "package.json": {
            "file": {
                "contents": '''{
  "name": "webcontainer-app",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --port 5173 --host",
    "build": "vite build"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.1",
    "vite": "^5.4.2"
  }
}'''
            }
        },
        "index.html": {
            "file": {
                "contents": '''<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>WebContainer App</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>'''
            }
        },
        "src": {
            "directory": {
                "main.jsx": {
                    "file": {
                        "contents": '''import React from 'react'
import ReactDOM from 'react-dom/client'

ReactDOM.createRoot(document.getElementById('root')).render(
  <div style={{fontFamily: 'sans-serif', padding: '2rem', textAlign: 'center'}}>
    <h1>🚀 App Built Successfully!</h1>
    <p>Generated for prompt: "''' + req.prompt.replace('"', '\\"') + '''"</p>
  </div>
)'''
                    }
                }
            }
        }
    }
