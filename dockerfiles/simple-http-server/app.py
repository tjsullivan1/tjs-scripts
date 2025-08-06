import os
from fastapi import FastAPI
import uvicorn

app = FastAPI(title="Environment Variables API", version="1.0.0")


@app.get("/")
def read_root():
    return {"message": "Hello! Visit /env to see environment variables"}


@app.get("/env")
def get_environment_variables():
    """Return all environment variables"""
    env_vars = dict(os.environ)
    return {"environment_variables": env_vars, "count": len(env_vars)}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
