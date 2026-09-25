---
name: whey
description: "Reading Givebutter data with the whey CLI. Use when a task needs campaigns, contacts, transactions, or other records from a Givebutter account, or mentions whey."
---

# Using whey

`whey` reads a Givebutter account through the public API. Every command is `list` or `get`, so it answers questions about the data and leaves the data unchanged.

Run `whey --help` for the resources and `whey <resource> --help` for nested ones and flags. That help is the source of truth for what exists.

## Output

Your output is piped, so `whey` prints JSON. `list` prints an array and `get` prints one object, each with every field the API returns. Filter with `jq`, as in `whey campaigns list --all | jq 'map(select(.status == "active")) | length'`. Parse JSON only. `-o csv` and `-o table` keep a fixed set of columns and drop the rest.

## Pagination

`list` returns the first page, 20 records, and prints no hint that more exist. For any count, total, search, or "every" question, add `--all` to fetch every page. `--per-page` takes 1 to 100 for a larger single page.

`--all` on a big account makes many requests. Narrow the list with filters first.

## Filters

`--param key=value` passes a query parameter straight to the API, and repeats for more than one. The parameter names come from the [API reference](https://docs.givebutter.com) for that endpoint.

```sh
whey transactions list --param method=card --param sortByDesc=amount
```

## Nested resources

A nested command takes the parent id first, then the record id.

```sh
whey campaigns members list <campaign-id>
whey campaigns members get <campaign-id> <member-id>
```

A 404 on a nested `get` usually means the record belongs to a different parent.

## Auth and errors

`whey auth status` checks the key against the API and names the account it belongs to and where the key came from. `GIVEBUTTER_API_KEY` wins over the key stored in the keychain.

Errors go to stderr as `whey: <message>`. Exit codes are `0` success, `1` error, and `4` missing or rejected API key. On exit `4`, stop and ask the human to run `whey auth login`, since it prompts for the key. On `429 Too Many Requests`, wait a minute before retrying.

`GIVEBUTTER_API_URL` points `whey` at another API host. If the data looks like the wrong account, run `whey auth status` and check `GIVEBUTTER_API_URL`.
