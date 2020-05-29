#! python3

import os
import fileinput


def get_email():
    if os.getlogin() == 'tisulliv':
        return 'tisulliv@microsoft.com'
    return 'timothyj.sullivan1@gmail.com'


def get_editor():
    vs_code_insiders = 'C:\\Users\\tisulliv\\AppData\\Local\\Programs\\Microsoft VS Code Insiders\\Code - Insiders.exe'
    vs_code = 'C:\\Program Files\\Microsoft VS Code\\Code.exe'
    if os.path.exists(vs_code_insiders):
        return vs_code_insiders
    if os.path.exists(vs_code):
        return vs_code

    return "vi"  # We default back to using VI if visual studio code isn't installed


def replace_file_contents(email, editor):
    with fileinput.FileInput('git-config.txt', inplace=True, backup='.bak') as config:
        for line in config:
            print(line.replace("{{email}}", email).replace("{{editor}}", repr(editor)), end='')

    return 0


def mv_git_config():
    cwd = os.getcwd()
    src = os.path.join(cwd, 'git-config.txt')
    bak = os.path.join(cwd, 'git-config.txt.bak')
    home = os.path.expanduser('~')
    dst = os.path.join(home, '.gitconfig')

    os.rename(src, dst)
    os.rename(bak, src)

    return 0


def main():
    email = get_email()
    editor = get_editor()
    replace_file_contents(email, editor)
    mv_git_config()
    

if __name__ == "__main__":
    main()


