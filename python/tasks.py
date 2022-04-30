#!/usr/bin/env python

import logging

import click
import requests


def get_rest_output(url, headers):
    logging.debug(f"here's the url {url}")
    return requests.get(url, headers=headers)


def build_headers(token):
    """
    We don't care if the token is actually passed or not, we'll get it from the environment.
    """
    if token == "ERROR: PLEASE DEFINE A TOKEN" or not token:
        raise Exception(
            "Token is not defined. Please either add an env variable MSGRAPH_TOKEN or use the --token switch"
        )

    headers = {"Authorization": "Bearer {0}".format(token)}

    return headers


def parse_result_list(response_list):
    parsed_lists = []
    for todo_list in response_list:
        parsed_dict = {"name": todo_list.get("displayName"), "id": todo_list.get("id")}
        parsed_lists.append(parsed_dict)

    return parsed_lists


def get_lists_tasks(list_of_dicts, url, headers):
    tasks_dicts = []
    completed_dicts = []

    for task_list in list_of_dicts:
        list_id = task_list.get("id")
        list_name = task_list.get("name")
        list_endpoint = f"{url}/{list_id}/tasks"

        tasks = []
        completed = []
        task_response = get_rest_output(list_endpoint, headers)

        for t in task_response.json().get("value"):
            task = t.get("title")
            if t.get("status") != "completed":
                tasks.append(task)
            
            if t.get("status") == "completed":
                completed.append(task)

        if tasks:
            task_dict = {"Name": list_name, "task_list": tasks}

            tasks_dicts.append(task_dict)
        
        if completed:
            completed_dict =  {"Name": list_name, "task_list": completed}

            completed_dicts.append(completed_dict)

    return tasks_dicts, completed_dicts


def convert_task_dict_to_markdown(task_dict):
    list_title = task_dict.get("Name")

    # TODO: bug - The first iter item does not receive the dash. Fix this.
    tasks_as_list = "\n- ".join(task_dict.get("task_list"))

    # TODO: enhance - list_title doesn't include the length of the icons that prefix the lists.
    return f"# {list_title}\n{'-'*(len(list_title) + 5)}\n{tasks_as_list}"


def make_human_readable(task_lists_list: list) -> str:
    markdown_outputs = []

    for task_list in task_lists_list:
        markdown_outputs.append(convert_task_dict_to_markdown(task_list))
    
    return '\n\n'.join(markdown_outputs)

# TODO: feature - offer options for exporting completed tasks, then delete completed tasks
@click.command()
@click.option(
    "--token", "-t", default=None, help="This is the bearer token for the graph API"
)
@click.option("--endpoint", "-e", default="me/todo/lists")
@click.option('-c', '--show-completed-tasks', 'completed', is_flag=True, default=False, help="Set this flag to display completed tasks.")
@click.option('-h', '--human-readable', 'human_readable', is_flag=True, default=False, help="Use this flag to make the output human readable.")
def main(token, endpoint, completed: bool, human_readable: bool):
    '''
    Note, for the most part this function could work for any graph call until we get to the todo piece.
    '''

    base_url = f"https://graph.microsoft.com/v1.0/{endpoint}"
    headers = build_headers(token)
    response = get_rest_output(base_url, headers)

    if endpoint == "me/todo/lists":
        response_list = response.json().get("value")
        parsed = parse_result_list(response_list)

        active_tasks, closed_tasks = get_lists_tasks(parsed, base_url, headers)
        
        if completed:
            if human_readable:
                click.echo(make_human_readable(closed_tasks))
            else:
                click.echo(closed_tasks)
        else:
            # click.echo(active_tasks)
            if human_readable:
                click.echo(make_human_readable(active_tasks))
            else:
                click.echo(active_tasks)

    pass


if __name__ == "__main__":
    main(auto_envvar_prefix="MSGRAPH")
