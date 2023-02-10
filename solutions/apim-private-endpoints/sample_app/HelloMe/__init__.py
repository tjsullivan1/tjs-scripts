import logging
import os

import azure.functions as func


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    # get an envinronment variable called "function_name"    
    name = os.environ.get('function_name', 'Currently undefined')

    return func.HttpResponse(f"{name}. This HTTP triggered function executed successfully.")
