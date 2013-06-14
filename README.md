# Tentd - Protocol v0.3 [![Build Status](https://travis-ci.org/tent/tentd.png?branch=0.3)](https://travis-ci.org/tent/tentd)

## Setup

**ENV Variables**

name         | required | description
------------ | -------- | -----------
TENT_ENTITY  | Required | Entity URI (can be omitted if `env['current_user']` is set to an instance of `TentD::Model::User` prior to `TentD::API::UserLookup` being called)
DATABASE_URL | Required | URL of postgres database (e.g. `postgres://localhost/tentd`)

**Running Server**

```bash
bundle exec puma
```

## Testing

**ENV Variables**

name                             | required | description
-------------------------------- | -------- | -----------
TEST_DATABASE_URL                | Required | URL of postgres database.
TEST_VALIDATOR_TEND_DATABASE_URL | Required | URL of postgres database.

**Running Tests**

```bash
bundle exec rake
```

