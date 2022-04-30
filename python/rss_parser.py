import csv
import datetime
from time import mktime

import feedparser

start_date = datetime.datetime.utcnow() - datetime.timedelta(30)

d = feedparser.parse(
    "https://support.microsoft.com/app/content/api/content/feeds/sap/en-us/c3a1be8a-50db-47b7-d5eb-259debc3abcc/atom"
)

with open("test.csv", "w", newline="") as csvfile:
    fieldnames = ["title", "link", "summary", "updated"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

    for entry in d.entries:
        entry_date = entry.updated_parsed
        dt = datetime.datetime.fromtimestamp(mktime(entry_date))
        if dt > start_date:
            writer.writerow(
                {
                    "title": entry.title,
                    "link": entry.link,
                    "summary": entry.summary,
                    "updated": entry.updated,
                }
            )
