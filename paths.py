"""Finds the data files, even if the GitHub upload changed the folder layout."""
from pathlib import Path

APP_FOLDER = Path(__file__).resolve().parent


def find_file(name):
    """Look for the file in this folder and its sub-folders, then one folder up."""
    for folder in (APP_FOLDER, APP_FOLDER.parent):
        matches = sorted(folder.rglob(name))
        if matches:
            return matches[0]
    return None
