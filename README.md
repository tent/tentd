# Tentd [![Build Status](https://travis-ci.org/tent/tentd.png?branch=0.3)](https://travis-ci.org/tent/tentd)

## Protocol version 0.3
To see the protocol documentation, see this [page](https://tent.io/docs)

##Requirements
TentD is written using Ruby 1.9 with Rack and Datamapper and is only tested with
PostgreSQL. The code needs a few fixes to work with 1.8 and other databases.

If you have Ruby 1.9, Bundler, and PostgreSQL installed, this should get the
tests running:

```shell
createdb tent_server_test
createdb tent_validator_test
bundle install
DATABASE_URL=postgres://localhost/tent_server_test rake db:migrate
DATABASE_URL=postgres://localhost/tent_validator_test rake db:migrate
DATABASE_URL=postgres://localhost/tent_server_test TEST_VALIDATOR_TEND_DATABASE_URL=postgres://localhost/tent_validator_test rake
```

remarks : 
- the tent_server_test database is used by tentd server to store your tent posts
- the tent_validator_test database is used by [tent-validator](https://github.com/tent/tent-validator)

## Contributions

If you want to help out with the TentD code instead of writing Tent clients and
applications, here are some areas that can be worked on:


### Contributors

- [Jonas Schneider](https://github.com/jonasschneider)