import azure.functions as func
import datetime
import json
import logging
import os

app = func.FunctionApp()

@app.route(route="HttpExample", methods=("GET","POST"), auth_level=func.AuthLevel.ANONYMOUS)
def HttpExample(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    body = None
    logging.info(f"Request method: {req.method}")
    logging.info(f"Request headers:")
    for header in req.headers:
        logging.info(f"{header}: {req.headers[header]}")
    logging.info(f"Request params: {req.params}")
    logging.info(f"Request route_params: {req.route_params}")

    # if req.headers.get('Fail-Request', False):
    #     return func.HttpResponse("This is a failed request", status_code=429)

    if not body:
        logging.info("Request body is empty. Trying to parse it from the request.")
        try:
            body = req.get_json()
        except ValueError:
            logging.info(f"Request body is not a JSON. Showing it nevertheless: {req.get_body()}")
            pass

    if body:
        return func.HttpResponse(f"This function is the FALLBACK function. This is the body that was passed to the function: \n{body}", status_code=200)
    else:
        return func.HttpResponse(
             "This HTTP triggered function executed successfully. Pass a body to see the proper response.",
             status_code=200
        )
    

@app.route(route="GraphExample", methods=("GET","POST"), auth_level=func.AuthLevel.ANONYMOUS)
def GraphExample(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    with open ("./sample.json", "r") as f:
        data = json.load(f)

    return func.HttpResponse(json.dumps(data), status_code=200)