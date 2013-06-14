# Tentd - Protocol v0.3 [![Build Status](https://travis-ci.org/tent/tentd.png?branch=0.3)](https://travis-ci.org/tent/tentd)

## Setup

### ENV Variables

name         | required | description
------------ | -------- | -----------
TENT_ENTITY  | Required | Entity URI (can be omitted if `env['current_user']` is set to an instance of `TentD::Model::User` prior to `TentD::API::UserLookup` being called)
DATABASE_URL | Required | URL of postgres database (e.g. `postgres://localhost/tentd`)
REDIS_URL    | Required | URL of redis server (e.g. `redis://localhost:6379`)
RUN_SIDEKIQ  | Optional | Set to 'true' if you want to boot sidekiq via `config.ru`
SIDEKIQ_LOG  | Optional | Sidekiq log file (defaults to STDOUT and STDERR)

### Database Setup

```bash
createdb tentd
DATABASE_URL=postgres://localhost/tentd bundle exec rake db:migrate
```

### Running Server

```bash
bundle exec puma
```

### Running Sidekiq

```bash
bundle exec sidekiq -r ./sidekiq.rb
```

or

```bash
RUN_SIDEKIQ=true bundle exec puma
```

## Testing

### ENV Variables

name                             | required | description
-------------------------------- | -------- | -----------
TEST_DATABASE_URL                | Required | URL of postgres database.
TEST_VALIDATOR_TEND_DATABASE_URL | Required | URL of postgres database.

### Running Tests

```bash
bundle exec rake
```

## Advanced

### Sidekiq Config

```ruby
# sidekiq client (see `config.ru`)
require 'tentd/worker'

# pass redis options directly
TentD::Worker.configure_client(:namespace => 'tentd.worker')

# access sidekiq config directly
TentD::Worker.configure_client do |sidekiq_config|
  # do stuff
end
```

```ruby
# sidekiq server (see `sidekiq.rb`)
require 'tentd/worker'

# pass redis options directly
TentD::Worker.configure_server(:namespace => 'tentd.worker')

# access sidekiq config directly
TentD::Worker.configure_server do |sidekiq_config|
  # do stuff
end
```

```ruby
# run sidekiq server from current proccess
require 'tentd/worker'

sidekiq_pid = TentD::Worker.run_server(:namespace => 'tentd.worker')

at_exit do
  Process.kill("INT", sidekiq_pid)
end
```

*Note that blocks are called after calling `config.redis = options` (see `lib/tentd/worker.rb`)*
