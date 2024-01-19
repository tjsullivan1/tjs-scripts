#!/usr/bin/env python

import click
import requests
from bs4 import BeautifulSoup


def get_page_html(url):
    html = requests.get(url)

    html.raise_for_status

    return BeautifulSoup(html.content, "html.parser")ls


def get_links(soup):
    results = soup.find(id="td-section-nav").find_all("a")
    links_array = []

    for link in results:
         link_url = link["href"]
         if len(link_url.split('/')) == 5:
             links_array.append(f"https://kubernetes.io{link_url}")

    return links_array


@click.command()
@click.option("-u", "--url", required=True, help="A quick description of the option")
def main(url: str):
    """ """
    html = get_page_html(url)
    links = get_links(html)

    print(links)
    pass


if __name__ == "__main__":
    main()
