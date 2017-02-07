# issue-bot

This bot is responsible for commenting on GitHub issues that haven't had any activity for multiple months.

## Configuration

Configuration is done via environment variables

* `REPO_TO_REAP` - The organisation and repo name you wish to use the bot on eg, `KitmanLabs/issue-bot`
*  `GITHUB_API_TOKEN` - A Github token from a user with access to the repo in `REPO_TO_REAP`. This will be the account that takes actions as the script.
