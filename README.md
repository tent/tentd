# Tentd - Protocol v0.3 [![Build Status](https://travis-ci.org/tent/tentd.png?branch=master)](https://travis-ci.org/tent/tentd)

**If you're looking to self-host, see [tentd-omnibus](https://github.com/tent/tentd-omnibus).**

## Setup

### ENV Variables

name            | required | description
--------------- | -------- | -----------
TENT_ENTITY     | Required | Entity URI (can be omitted if `env['current_user']` is set to an instance of `TentD::Model::User` prior to `TentD::API::UserLookup` being called)
DATABASE_URL    | Required | URL of postgres database (e.g. `postgres://localhost/tentd`)
REDIS_URL       | Required | URL of redis server (e.g. `redis://localhost:6379`)
REDIS_NAMESPACE | Optional | Redis key namespace for sidekiq (defaults to `tentd.worker`)
RUN_SIDEKIQ     | Optional | Set to 'true' if you want to boot sidekiq via `config.ru`
SIDEKIQ_LOG     | Optional | Sidekiq log file (defaults to STDOUT and STDERR)
SOFT_DELETE     | Optional | To perminently delete db records, set to `false`. Defaults to `true` (sets `deleted_at` timestamp instead of removing from db)

#### Attachment Storage Options

Precedence is in the same order as listed below.

name       | env                              | description
----       | ---                              | -----------
Amazon S3  | AWS_ACCESS_KEY_ID                | Access key identifier
           | AWS_SECRET_ACCESS_KEY            | Access key
           | S3_BUCKET                        | Bucket name
Google     | GOOGLE_STORAGE_ACCESS_KEY_ID     | Access key identifier
           | GOOGLE_STORAGE_SECRET_ACCESS_KEY | Access key
           | GOOGLE_BUCKET                    | Bucket name
Rackspace  | RACKSPACE_USERNAME               | Username
           | RACKSPACE_API_KEY                | Api key
           | RACKSPACE_AUTH_URL               | Auth URL (European Rackspace)
           | RACKSPACE_CONTAINER              | Container (bucket) name
Filesystem | LOCAL_ATTACHMENTS_ROOT           | Path to directory (e.g. `~/tent-attachments`)
Postgres   | POSTGRES_ATTACHMENTS             | Default. Set to `true` to override any of the other options.

### Database Setup

```bash
createdb tentd
DATABASE_URL=postgres://localhost/tentd bundle exec rake db:migrate
```

### Running Server

```bash
bundle exec unicorn
```

### Running Sidekiq

```bash
bundle exec sidekiq -r ./sidekiq.rb
```

or

```bash
RUN_SIDEKIQ=true bundle exec unicorn
```

### Heroku

```bash
heroku create --addons heroku-postgresql:dev,rediscloud:20
heroku pg:promote $(heroku pg | head -1 | cut -f2 -d" ")
heroku config:add TENT_ENTITY=$(heroku info -s | grep web_url | cut -f2 -d"=" | sed 's/http/https/' | sed 's/\/$//')
git push heroku master
heroku run rake db:migrate
```

*Note: You will need to checkin `Gemfile.lock` after running `bundle install` to push to heroku*

## Testing

### ENV Variables

name                             | required | description
-------------------------------- | -------- | -----------
TEST_DATABASE_URL                | Required | URL of postgres database.
TEST_VALIDATOR_TEND_DATABASE_URL | Required | URL of postgres database.
REDIS_URL                        | Optional | Defaults to `redis://localhost:6379/0`. A redis server is required.

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

## Contributing

- Refactor. The current code was hacked together quickly and is pretty ugly.
