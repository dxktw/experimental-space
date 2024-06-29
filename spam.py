import os
import time
import random
from github import Github

# GitHub access token
github_access_token = "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"

# Path to the empty file
file_path = ".tmp"

# Create a GitHub instance using the access token
g = Github(github_access_token)

# Get a list of all repositories for the authenticated user
repos = list(g.get_user().get_repos())

# Shuffle the repositories
random.shuffle(repos)

# Calculate the total number of commits desired (500-1500 range)
total_commits = random.randint(5, 50)

# Initialize variables to keep track of commits made and repositories used
commits_made = 0
repos_used = 0

while commits_made < total_commits and repos_used < len(repos):
    repo = repos[repos_used]
    print("Working with repository:", repo.full_name)

    # Randomly determine the number of commits to make for this repository
    commits_in_this_repo = random.randint(1, 3)

    for _ in range(commits_in_this_repo):
        # Add the empty file
        with open(file_path, 'w') as file:
            file.write("")  # Empty contents

        # Commit the file to the repository
        try:
            repo.create_file(".tmp", "Initial commit", "")
            print("Empty file added to the repository.")

            # Wait for a few seconds to ensure the commit is processed
            time.sleep(3)

            # Delete the file from the repository
            contents = repo.get_contents(".tmp")
            repo.delete_file(contents.path, "Removing file", contents.sha)
            print("Empty file deleted from the repository.")

            # Wait for a few seconds to ensure the commit is processed
            time.sleep(3)

            commits_made += 1

        except Exception as e:
            print("An error occurred:", e)

    repos_used += 1

print(f"Total commits made: {commits_made}")
