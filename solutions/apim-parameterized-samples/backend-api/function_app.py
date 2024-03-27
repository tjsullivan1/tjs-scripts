import azure.functions as func
import datetime
import json
import logging

app = func.FunctionApp()

@app.route(route="HttpExample", auth_level=func.AuthLevel.ANONYMOUS)
def HttpExample(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    body = None
    logging.info(f"Request method: {req.method}")
    logging.info(f"Request headers:")
    for header in req.headers:
        logging.info(f"{header}: {req.headers[header]}")
    logging.info(f"Request params: {req.params}")
    logging.info(f"Request route_params: {req.route_params}")

    if not body:
        logging.info("Request body is empty. Trying to parse it from the request.")
        try:
            body = req.get_json()
        except ValueError:
            logging.info(f"Request body is not a JSON. Showing it nevertheless: {req.get_body()}")
            pass

    if body:
        return func.HttpResponse(f"This is the body that was passed to the function: \n{body}", status_code=200)
    else:
        return func.HttpResponse(
             "This HTTP triggered function executed successfully. Pass a body to see the proper response.",
             status_code=200
        )