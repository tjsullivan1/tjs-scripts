import os
import json
import uuid

from dotenv import load_dotenv
from azure.cosmos import CosmosClient, PartitionKey

from faker import Faker

load_dotenv()

fake = Faker()

def generate_fake_item():
    id_uuid = str(uuid.uuid4())
    pk_uuid = str(uuid.uuid4())
    return {
        "id": id_uuid,
        "pk": pk_uuid,
        "categoryName": fake.word(),
        "name": fake.word(),
        "quantity": fake.random_int(min=0, max=100),
        "sale": fake.boolean(),
    }

def main():
    ENDPOINT = os.environ["COSMOS_ENDPOINT"]
    KEY = os.environ["COSMOS_KEY"]

    DATABASE_NAME = "bulk-tutorial"
    CONTAINER_NAME = "items"

    client = CosmosClient(url=ENDPOINT, credential=KEY)

    database = client.create_database_if_not_exists(id=DATABASE_NAME)
    print("Database\t", database.id)

    key_path = PartitionKey(path="/pk")

    container = database.create_container_if_not_exists(
        id=CONTAINER_NAME, partition_key=key_path, offer_throughput=400
    )
    print("Container\t", container.id)

    for _ in range(1000):
        new_item = generate_fake_item()
        container.create_item(new_item)

if __name__ == "__main__":
    main()