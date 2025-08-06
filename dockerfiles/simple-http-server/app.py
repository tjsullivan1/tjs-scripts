import os
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import uvicorn

app = FastAPI(title="Environment Variables API", version="1.0.0")


@app.get("/")
def read_root():
    return {"message": "Hello! Visit /env to see environment variables"}


@app.get("/env", response_class=HTMLResponse)
def get_environment_variables():
    """Return all environment variables with bold names and plaintext values"""
    env_vars = dict(os.environ)

    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Environment Variables</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .env-var { margin: 5px 0; }
            .var-name { font-weight: bold; }
            .var-value { margin-left: 10px; }
        </style>
    </head>
    <body>
        <h1>Environment Variables ({count})</h1>
        <div>
    """.format(
        count=len(env_vars)
    )

    for name, value in sorted(env_vars.items()):
        html_content += f'        <div class="env-var"><span class="var-name">{name}:</span> <span class="var-value">{value}</span></div>\n'

    html_content += """
        </div>
    </body>
    </html>
    """

    return html_content


@app.get("/health")
def health_check():
    return {"status": "healthy"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
