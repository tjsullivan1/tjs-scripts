import typer
from typing_extensions import Annotated
import requests
import os
import json
from dotenv import load_dotenv

load_dotenv()

def build_url(subId, location):
    return f"https://management.azure.com/subscriptions/{subId}/providers/Microsoft.CognitiveServices/locations/{location}/usages?api-version=2023-05-01"

def build_headers(access_token):
    return {
        'accept': 'application/json',
        'Authorization': f'Bearer {access_token}',
    }

def get_model_info(json_str, model_name):
    data = json.loads(json_str)
    data = data.get('value', [])
    for item in data:
        if item.get('name', {}).get('value', '') == model_name:
            return item
    return None

def get_remaining_capacity(model_match):
   
    used_capacity = model_match.get('currentValue', 0)
    total_capacity = model_match.get('limit', 0)
    remaining_capacity = total_capacity - used_capacity

    # print(f"Used Capacity: {used_capacity}")
    # print(f"Total Capacity: {total_capacity}")
    # print(f"Remaining Capacity: {remaining_capacity}")

    return remaining_capacity


def main(
    model_name: Annotated[str, typer.Option(help="Model Name.")],
    subId: Annotated[str, typer.Option(help="Azure Subscription ID.")] = "",
    location: Annotated[str, typer.Option(help="Azure Region.")] = "",
    access_token: Annotated[str, typer.Option(help="Azure Access Token.")] = "",
):
    if not subId:
        subId = os.getenv("SUBSCRIPTION_ID", "")
    if not location:
        location = os.getenv("LOCATION", "")
    if not access_token:
        access_token = os.getenv("ACCESS_TOKEN", "")

    url=build_url(subId, location)

    headersAPI = build_headers(access_token)

    response = requests.get(url, headers=headersAPI)

    model_match = get_model_info(response.text, model_name)

    remaining = get_remaining_capacity(model_match)

    my_values = {
        "model_name": model_name,
        "remaining": str(remaining) # Terraform requires these to be strings
    }

    print(json.dumps(my_values))


if __name__ == "__main__":
    typer.run(main)