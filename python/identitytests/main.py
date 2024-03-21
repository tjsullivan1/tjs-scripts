import os
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv


# This script requires four environment variables to be set, either in a .env or actually in the environment to run LOCALLY
# AZURE_CLIENT_ID
# AZURE_CLIENT_SECRET
# AZURE_TENANT_ID
# SCOPE
# If running on K8s or in Azure, ONLY SCOPE is needed. The others can use a managed identity.
if ( os.getenv('ENVIRONMENT')== 'development'):
    print("Loading environment variables from .env file")
    load_dotenv("dev.env")  # take environment variables from .env.

credential = DefaultAzureCredential()

scope = os.getenv("SCOPE")
token = credential.get_token(scope)

print(token.token)

