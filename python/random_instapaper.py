import os
import random

import click
from instapaper import Instapaper as ipaper


def get_secrets_from_env():
    key = os.environ.get("INSTAPAPER_KEY")
    secret = os.environ.get("INSTAPAPER_SECRET")
    email = os.environ.get("INSTAPAPER_EMAIL")
    password = os.environ.get("INSTAPAPER_PASSWORD")

    return key, secret, email, password


@click.command()
@click.option("--from-env", "-e")
def main(from_env):
    (
        instapaper_key,
        instapaper_secret,
        instapaper_email,
        instapaper_password,
    ) = get_secrets_from_env()

    i = ipaper(instapaper_key, instapaper_secret)
    i.login(instapaper_email, instapaper_password)

    marks = i.bookmarks(limit=500)

    randomly_selected = random.randint(0, (len(marks) - 1))

    selected = f"https://www.instapaper.com/read/{marks[randomly_selected].bookmark_id}"

    click.echo(len(marks))
    click.echo(selected)


if __name__ == "__main__":
    main()
