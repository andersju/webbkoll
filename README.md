# Webbkoll

This is the code that powers https://webbkoll.dataskydd.net/en - an
online tool that checks how a webpage is doing with regards to privacy.

It attempts to simulate what happens when a user visits a specified page 
with a typical browser, without clicking on anything, and with the
browser having no particular extensions installed, and with Do Not Track
(DNT) disabled - as this is the default in most browsers.

In short: frontend (Phoenix) asks backend (PhearJS) to visit a page with
PhantomJS. Backend visits and renders page, collects various data
(requests made, cookies, response headers, etc.), and sends it back as
JSON to the frontend which analyzes the data and presents the results
on a webpage along with explanations and advice.

The frontend is multilingual and currently supports English and Swedish.

[exq](https://github.com/akira/exq) is used for job processing, and
some basic rate limiting is done with [ex_rated](https://github.com/grempe/ex_rated).
Multiple backends can be configured.

**Please note** that this is still a work in progress. Expect bugs and
messy code in places. Only a few basic tests are in place.
Cleanup is underway!

**Also note** that this tool is mainly meant to be used as a _starting point_
for web developers. For more rigorous and systematic testing we
recommend that you check out [OpenWPM](https://github.com/citp/OpenWPM), which we used to analyze the
websites of Sweden's municipalities ([site](https://dataskydd.net/kommuner/), [code](https://github.com/andersju/municipality-privacy)).

## Backend
  * Get PhearJS running - see https://github.com/Tomtomgo/phearjs/blob/master/README.md. (Clone https://github.com/andersju/phearjs/ to get the one that Dataskydd.net is running.)

## Ruby client
If you just want the data in a machine-readable form, you only need
PhearJS and the simple client written in Ruby in `misc/ruby-client`:

  * Make sure Ruby is installed on your system and that PhearJS is running. Then, in `misc/ruby-client`:
  * Install dependencies: `bundle install`
  * To see possible options, run `ruby webbkoll.rb --help`
  * Example: `ruby webbkoll.rb http://www.example.com`
  * By default the backend is `http://localhost:8100` and the program will output JSON to STDOUT.
  * Please note that it's currently _very_ basic.

## Frontend (this app!)
  * Install Erlang (18) and Elixir (>= 1.2.4) -- see http://elixir-lang.org/install.html
  * Have [redis](http://redis.io/) running (needed for exq job handling)
  * Make sure you have a working [PostgreSQL](http://www.postgresql.org/) installation
  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `npm install`
  * Make sure PhearJS and redis are running on the hosts/ports specified in `config/dev.exs`
  * Start Phoenix endpoint with `mix phoenix.server` (or in an interactive shell: `iex -S mix phoenix.server`)

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To run in production, create `config/prod.secret.exs` and enter something like the following (edit `secret_key_base` and change database configuration as necessary):
```
use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
config :webbkoll, Webbkoll.Endpoint,
  secret_key_base: "somelongrandomstring"

# Configure your database
config :webbkoll, Webbkoll.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "webbkoll_prod",
  pool_size: 20
```

Create and migrate database:

  * `MIX_ENV=prod mix ecto.create`
  * `MIX_ENV=prod mix ecto.migrate`

Compile static assets:

  * `node_modules/brunch/bin/brunch build --production`
  * `MIX_ENV=prod mix phoenix.digest`

Compile application:

  * `MIX_ENV=prod mix compile`

Finally, start the server:

  * `PORT=4001 MIX_ENV=prod mix phoenix.server`

Or start the server in an interactive shell:

  * `PORT=4001 MIX_ENV=prod iex -S mix phoenix.server`

See also the official [Phoenix deployment guides](http://www.phoenixframework.org/docs/deployment).

## Credits & things used
  * [Phoenix Framework](http://www.phoenixframework.org/) (MIT license) by Chris McCord
  * [Bourbon](https://github.com/thoughtbot/bourbon), [Neat](https://github.com/thoughtbot/neat), [Bitters](https://github.com/thoughtbot/bitters), [Refills](https://github.com/thoughtbot/refills) (MIT license) by thoughtbot
  * [Sortable](https://github.com/HubSpot/sortable) (MIT license) by Adam Schwartz
  * [Font Awesome](https://fortawesome.github.io/Font-Awesome/) (SIL OFL 1.1) by Dave Gandy
  * [Source Sans Pro](https://github.com/adobe-fonts/source-sans-pro) (SIL OFL 1.1) by Adobe Systems
  * [Disconnect's open source list of trackers](https://github.com/disconnectme/disconnect-tracking-protection) (GPLv3) by Disconnect, Inc.

## License
    The MIT License (MIT)

    Copyright (c) 2016 Anders Jensen-Urstad

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
