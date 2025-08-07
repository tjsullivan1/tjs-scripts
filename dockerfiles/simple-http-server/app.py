import os
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
import uvicorn

app = FastAPI(title="Environment Variables API", version="1.0.0")
templates = Jinja2Templates(directory="templates")


@app.get("/")
def read_root():
    computer_name = os.getenv("COMPUTERNAME", "Undefinded Computername")
    host_name = os.getenv("HOSTNAME", "Undefinded Hostname")
    website_default_host = os.getenv(
        "APPSETTING_WEBSITE_DEFAULT_HOSTNAME", "Undefinded Website Hostname"
    )
    return {
        "message": f"Hello! Visit /env to see environment variables like COMPUTERNAME: {computer_name}, HOSTNAME: {host_name}, and APPSETTING_WEBSITE_DEFAULT_HOSTNAME: {website_default_host}",
    }


@app.get("/env", response_class=HTMLResponse)
def get_environment_variables(request: Request):
    """Return all environment variables with bold names and plaintext values using Jinja2"""
    env_vars = sorted(os.environ.items())

    return templates.TemplateResponse(
        "env_vars.html", {"request": request, "env_vars": env_vars}
    )


@app.get("/health")
def health_check():
    return {"status": "healthy"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
