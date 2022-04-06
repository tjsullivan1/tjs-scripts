#!/usr/bin/env python

import requests
import click
import urllib.parse
import json

from datetime import datetime

from notion_database.children import Children
from notion_database.database import Database
from notion_database.page import Page
from notion_database.properties import Properties

import ast

def generate_google_book_api_url(title, results):
    return f'https://www.googleapis.com/books/v1/volumes?q={urllib.parse.quote_plus(title)}&maxResults={results}'


def get_books(api):
    results = requests.get(api)
    results.raise_for_status()

    return results.json().get('items')


def parse_volume_info(volume, status, referral=None, priority='Low', rating=0, form_factor='Audiobook', date=None, category='Personal'):
    today = datetime.today()
    added_date = f"{today.month}/{today.day}/{today.year}"

    if date is None or status != 'read':
        date_read = ''
    else:
        date_read = date
    
    book_as_dict = {
        'Title': volume.get('title'),
        'Author': volume.get('authors'),
        'Referral': referral,
        'Genre': volume.get('categories'),
        'Status': status,
        'Priority': priority,
        'Rating': rating,
        'Type Read': form_factor,
        'Date Read': date_read,
        'Date Added': added_date,
        'Category': category,
    }
    
    return book_as_dict


def add_to_notion(book_info, database_id, notion_key):
    author_string = ", "

    if book_info.get('Referral') is None:
        # The notion API throws errors if this value is null (or it could be the python package I'm using, 
        # so if we have no referral set to a space)
        referral = ' '
    else:
        referral = book_info.get('Referral')

    if type(book_info.get('Genre')) == list:
        genres = ""
        genres = genres.join(book_info.get('Genre')).replace(',',':')
    else:
        genres = book_info.get('Genre')

    if book_info.get('Genre') is None:
        genres = 'Random'

    PROPERTY = Properties()
    PROPERTY.set_title('Title', book_info.get('Title'))
    PROPERTY.set_rich_text('Author', author_string.join(book_info.get('Author')))
    PROPERTY.set_rich_text('Referred From', referral)
    PROPERTY.set_select('Genre', genres)
    PROPERTY.set_select('Status', book_info.get('Status'))
    PROPERTY.set_select('Priority', book_info.get('Priority'))
    PROPERTY.set_number('Rating out of 5', str(book_info.get('Rating')))
    PROPERTY.set_multi_select('Type Read', [book_info.get('Type Read')])
    PROPERTY.set_select('Category', book_info.get('Category'))
    # TODO: Get data read property added

    # Create Page
    P = Page(integrations_token=notion_key)
    P.create_page(database_id=database_id, properties=PROPERTY)

    return 0


# TODO: Search by more than just title
@click.command()
@click.option('--title', '-t')
@click.option('--status', '-s', default='to-read', type=click.Choice(['to-read', 'read', 'not-to-read', 'currently-reading'], case_sensitive=False))
@click.option('--date-read', default=None, help="When did you read the book? Formatted in MM/DD/YYYY.")
@click.option('--referral', '--referred-by', help="Who told you about this or where did you find this reference?")
@click.option('--result-size', '--results', '-r', default=1, help='How many book json objects do we want to return?')
@click.option('--notion-key', '-nk', help="This is the integration key for Notion that allows writes to the database.")
@click.option('--notion-database', '-ndb', help="This is the database ID that maps to your desired database.")
@click.option('--no-notion', '-nn', is_flag=True, default=None, help='Use this flag to skip adding to Notion')
def main(title: str, status: str, date_read: str, referral: str, result_size: int, notion_key: str, notion_database: str, no_notion):
    google_book_api_url=generate_google_book_api_url(title, result_size)

    books = get_books(google_book_api_url)

    for book in books:
        book_info = parse_volume_info(book.get('volumeInfo'), referral=referral, status=status, date=date_read)
        print(book_info)

        if no_notion is None:
            add_to_notion(book_info=book_info, database_id=notion_database, notion_key=notion_key)

    pass


if __name__ == '__main__':
    main(auto_envvar_prefix='BOOKS')
