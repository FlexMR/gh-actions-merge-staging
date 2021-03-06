# Merge Staging Action

When a `staging` label is added to a PR the PR will automatically be merged into a branch named `staging` via a GitHub Action.

A comment will automatically be added to reflect that this has happened (or failed).

## Installation

To enable the action simply create the `.github/workflows/merge-staging.yml`
file with the following content:

```yml
name: 'Merge to staging'

on:
  pull_request:
    types: [labeled]

jobs:
  merge-command:
    if: contains(github.event.label.name, 'staging')
    runs-on: ubuntu-latest

    steps:
    - name: Checkout
      uses: actions/checkout@v1

    - name: Merge staging command
      uses: FlexMR/gh-actions-merge-staging@master
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
