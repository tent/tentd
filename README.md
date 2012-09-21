# tentd [![Build Status](https://secure.travis-ci.org/tent/tentd.png)](http://travis-ci.org/tent/tentd)

tentd is an **alpha** implementation of a [Tent Protocol](http://tent.io) server.
It currently contains **broken code, ugly code, many bugs, and security flaws**.
The code should only be used to experiment with how Tent works. Under no
circumstances should the code in its current form be used for data that is
supposed to be private. All of the implemented APIs are in flux, and are
expected to change heavily before the Tent 1.0 release.


## Requirements

TentD is written using Ruby 1.9 with Rack and Datamapper and is only tested with
PostgreSQL. The code needs a few fixes to work with 1.8 and other databases.

If you have Ruby 1.9, Bundler, and PostgreSQL installed, this should get the
tests running:

```shell
createdb tent_server_test
bundle install
rake
```

If you want to run this as a Tent server, you should use
[tentd-admin](https://github.com/tent/tentd-admin).


## Contributions

If you want to help out with the TentD code instead of writing Tent clients and
applications, here are some areas that can be worked on:

- Fix database queries. There are a bunch of suboptimal uses of the database,
  and basically no indexes. Low hanging fruit would be to turn on logging while
  running the tests and index all the queries.
- Add data validation/normalization.
- Audit security.
- Refactor. The current code was hacked together quickly and is pretty ugly.
- Add tests. There are quite a few areas that aren't tested completely.
- Fix tests. A lot of tests are written as integration tests and depend on the
  database, many would be much faster as unit tests that don't hit the database.

Please note that we are not looking for Pull Requests that make fundamental
changes to how the Tent Protocol works.

### Contributors

- [Jonas Schneider](https://github.com/jonasschneider)
