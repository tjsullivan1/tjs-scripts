#!/usr/bin/env python

import os
import random

import typer
from instapaper import Instapaper as ipaper


app = typer.Typer(
    name="Instapaper API",
    add_completion=False,
    help="This is a app for doing things with Instapaper.",
)


def build_context(key, secret, email, password):
    i = ipaper(key, secret)
    i.login(email, password)

    return i


@app.command("random", help="Get a random article from your instapaper list.")
def random_article(
    key: str = typer.Option(
        ...,
        "--key",
        "-k",
        envvar="INSTAPAPER_KEY",
        help="This is the api key for your instapaper application.",
    ),
    secret: str = typer.Option(
        ...,
        "--secret",
        "-s",
        envvar="INSTAPAPER_SECRET",
        hide_input=True,
        help="This is secret that corresponds to the instapaper application key.",
    ),
    email: str = typer.Option(..., "--email", "-e", envvar="INSTAPAPER_EMAIL",help="The user's email address."),
    password: str = typer.Option(
        ..., "--password", "-p", envvar="INSTAPAPER_PASSWORD", help="The user's password.", hide_input=True
    ),
):
    i = build_context(key=key, secret=secret, email=email, password=password)

    marks = i.bookmarks(limit=500)

    #  (this isn't a cryptogtraphic function so we don't care that we're using random)
    randomly_selected = random.randint(0, (len(marks) - 1))  # nosec

    selected = f"https://www.instapaper.com/read/{marks[randomly_selected].bookmark_id}"

    typer.echo(selected)


@app.command()
def all(
    key: str = typer.Option(
        ...,
        "--key",
        "-k",
        envvar="INSTAPAPER_KEY",
        help="This is the api key for your instapaper application.",
    ),
    secret: str = typer.Option(
        ...,
        "--secret",
        "-s",
        envvar="INSTAPAPER_SECRET",
        hide_input=True,
        help="This is secret that corresponds to the instapaper application key.",
    ),
    email: str = typer.Option(..., "--email", "-e", envvar="INSTAPAPER_EMAIL",help="The user's email address."),
    password: str = typer.Option(
        ..., "--password", "-p", envvar="INSTAPAPER_PASSWORD", help="The user's password.", hide_input=True
    ),
):
    i = build_context(key=key, secret=secret, email=email, password=password)
    marks = i.bookmarks(limit=500)

    typer.echo(len(marks))


if __name__ == "__main__":
    app(auto_envvar_prefix="INSTAPAPER")
