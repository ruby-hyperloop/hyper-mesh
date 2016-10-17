# Synchromesh ![](logo.jpg?raw=true)

[Synchromesh](https://en.wikipedia.org/wiki/Manual_transmission#Synchromesh) provides multi-client synchronization for [reactive-record.](https://github.com/catprintlabs/reactive-record)

In other words browser 1 creates, updates, or destroys a model, and the changes are broadcast to all other clients.

Add the gem, setup your configuration, and synchromesh does the rest.

## Quick Start Guides

Use one of the following guides if you are in a hurry to get going.

The easiest way to get setup is to use the Pusher-Fake gem.  Get started with this [guide.](docs/pusher_faker_quickstart.md)

If you are already using Pusher follow this [guide.](docs/pusher_quickstart.md)

If you are on Rails 5 already, and want to try ActionCable use this [guide.](docs/action_cable_quickstart.md)

All of the above use websockets.  For ultimate simplicity use Polling as explained [here.](docs/simple_poller_quickstart.md)

## Overview

Synchromesh is built on top of Reactrb and ReactiveRecord.

+ Reactrb is a ruby wrapper on Facebook's React.js library.  As data changes on the client (either from user interactions or external events) Reactrb re-draws whatever parts of the display as needed.
+ ReactiveRecord uses Reactrb to render and then dynamically update your ActiveRecord models on the client.
+ Synchromesh broadcasts any changes to your ActiveRecord models as they are persisted on the server.

A minimal synchromesh configuration consists of a simple initializer file, and at least one *Policy* class that will *authorize* who gets to see what.

The initializer file specifies what transport will be used.  Currently you can use [Pusher](http://pusher.com), ActionCable (if using Rails 5), Pusher-Fake (for development) or a Simple Poller for testing etc.

Synchromesh also adds some features to the `ActiveRecord` `scope` method to manage scopes updates.  Details [here.](docs/client_side_scoping.md)  

## Authorization

Each application defines a number of *channels* and *authorization policies* for those channels and the data sent over the channels.

Policies are defined with *Policy* classes.  These are similar and compatible with [Pundit](https://github.com/elabs/pundit) but
you do not need to use the pundit gem (but can if you want.)

Examples:

```ruby
class ApplicationPolicy
  # define policies for the Application

  # all clients can connect to the Application
  always_allow_connection
end

class ProductionCenterPolicy
  # define policies for the ProductionCenter model

  # any time a ProductionCenter model is updated
  # broadcast the total_jobs_shipped attribute over the
  # application channel (i.e. this is public data anybody can see)
  regulate_broadcast do |policy|
    policy.send_only(:total_jobs_shipped).to(Application)
  end
end

class UserPolicy
  # define policies for the User channel and Model

  # connect a channel for each logged in user
  regulate_instance_connection { self }

  # users can see all but one field of their own data
  regulate_broadcast do |policy|
    policy.send_all_but(:gross_margin_contribution).to(self)
  end
end
```

For complete details see [Authorization Policies](docs/authorization-policies.md)

## Installation

If you do not already have reactrb installed, then use the reactrb-rails-generator gem to setup reactrb, reactive-record and associated gems.

Then add this line to your application's Gemfile:

```ruby
gem 'synchromesh'
```

And then execute:

    $ bundle install

Also you must `require 'synchromesh'` from your client side code.  The easiest way is to
find the `require 'reactive-record'` line (typically in `components.rb`) and add `require 'synchromesh'` directly below it.  

## Configuration

Add an initializer like this:

```ruby
# for rails this would go in: config/initializers/synchromesh.rb
Synchromesh.configuration do |config|
  config.transport = :simple_poller # or :none, action_cable, :pusher - see below)
end
# for a minimal setup you will need to define at least one channel, which you can do
# in the same file as your initializer.
# Normally you would put these policies in the app/policies/ directory
class ApplicationPolicy
  # allow all clients to connect to the Application channel
  regulate_connection { true } # or always_allow_connection for short
  # broadcast all model changes over the Application channel *DANGEROUS*
  regulate_all_broadcasts { |policy| policy.send_all }
end
```

### Action Cable Configuration

If you are on Rails 5 you can use ActionCable out of the box.

```ruby
#config/initializers/synchromesh.rb
Synchromesh.configuration do |config|
  config.transport = :action_cable
end
```

If you have not yet setup action cable all you have to do is include the `action_cable` js file in your assets

```javascript
//application.js
...
//= require action_cable
...
```

The rest of the setup will be handled by Synchromesh.

Synchromesh will not interfere with any ActionCable connections and channels you may have already defined.  

### Pusher Configuration

Add `gem 'pusher'` to your gem file, and add `//= require 'synchromesh/pusher'` to your application.js file.

```ruby
# typically config/initializers/synchromesh.rb
Synchromesh.configuration do |config|
  config.transport = :pusher
  config.opts = {
    app_id: '2xxxx2',
    key:    'dxxxxxxxxxxxxxxxxxx9',
    secret: '2xxxxxxxxxxxxxxxxxx2',
    encrypted: false # optional defaults to true
  }
  config.channel_prefix = 'syncromesh' # or any other string you want
end
```

### Pusher-Fake

You can also use the [Pusher-Fake](https://github.com/tristandunn/pusher-fake) gem while in development.  Setup is a little tricky.  First
add `gem 'pusher-fake'` to the development and/or test section of your gem file. Then setup your config file:

```ruby
# typically config/initializers/synchromesh.rb
# or you can do a similar setup in your tests (see this gem's specs)
require 'pusher'
require 'pusher-fake'
# The app_id, key, and secret need to be assigned directly to Pusher
# so PusherFake will work.
Pusher.app_id = "MY_TEST_ID"      # you use the real or fake values
Pusher.key =    "MY_TEST_KEY"
Pusher.secret = "MY_TEST_SECRET"
# The next line actually starts the pusher-fake server (see the Pusher-Fake readme for details.)
require 'pusher-fake/support/base' # if using pusher with rspec change this to pusher-fake/support/rspec
# now copy over the credentials, and merge with PusherFake's config details
Synchromesh.configuration do |config|
  config.transport = :pusher
  config.channel_prefix = "synchromesh"
  config.opts = {
    app_id: Pusher.app_id,
    key: Pusher.key,
    secret: Pusher.secret
  }.merge(PusherFake.configuration.web_options)
end
```

### Simple Poller Details

Setup your config like this:
```ruby
Synchromesh.configuration do |config|
  config.transport = :simple_poller
  config.channel_prefix = "synchromesh"
  config.opts = {
    seconds_between_poll: 5, # default is 0.5 you may need to increase if testing with Selenium
    seconds_polled_data_will_be_retained: 1.hour  # clears channel data after this time, default is 5 minutes
  }
end
```

## The Cache store

Synchromesh uses the rails cache to keep track of what connections are alive in a transport independent fashion.  Rails 5 by default will have caching off in development mode.

Check in `config/development.rb` and make sure that `cache_store` is never being set to `:null_store`.  

If you would like to be able to interact via
the `rails console` you should set the store to be something like this:

```ruby
# config/development.rb
Rails.application.configure do
  ...
  config.cache_store = :file_store, './rails_cache_dir'
  ...
end
```

## Common Errors

- No policy class:  
If you don't define a policy file, nothing will happen because nothing will get connected.  
By default synchromesh will look for a `ApplicationPolicy` class.
- Wrong version of pusher-fake  (pusher-fake/base vs. pusher-fake/rspec)  
See the Pusher-Fake gem repo for details.
- Forgetting to add require pusher in application.js file  
this results in an error like this:
```text
Exception raised while rendering #<TopLevelRailsComponent:0x53e>
    ReferenceError: Pusher is not defined
```  
To resolve make sure you `require 'pusher'` in your application.js file if using pusher.
- No create/update/destroy policies
You must explicitly allow changes to the models to be made by the client. If you don't you will
see 500 responses from the server when you try to update.  To open all access do this in
your application policy: `allow_change(to: :all, on: [:create, :update, :destroy]) { true }`
- `Cannot Run Synchromesh with cache_store == :null_store`  
You will get this error on boot if you are trying to use the :null cache.  
See notes above on why you cannot use the :null cache store.
- Cannot connect to real pusher account:  
If you are trying to use a real pusher account (not pusher-fake) but see errors like this  
```text
pusher.self.js?body=1:62 WebSocket connection to
'wss://127.0.0.1/app/PUSHER_API_KEY?protocol=7&client=js&version=3.0.0&flash=false'
failed: Error in connection establishment: net::ERR_CONNECTION_REFUSED
```
Check to see if you are including the pusher-fake gem.  
Synchromesh will always try to use pusher-fake if it sees the gem included.  Remove it and you should be good to go.  See [issue #5](https://github.com/reactrb/synchromesh/issues/5) for more details.

## Debugging

Sometimes you need to figure out what connections are available, or what attributes are readable etc.

Its all to do with your policies, but perhaps you just need a little investigation.

You can bring up a console within the controller context by browsing `localhost:3000/rr/console`

*Note:  change `rr` to wherever you are mounting reactive record in your routes file.*

*Note: in rails 4, you will need to add the gem 'web-console' to your development section*

Within the context you have access to `session.id` and current `acting_user` which you will need, plus some helper methods to reduce typing

- Getting auto connection channels:  
`channels(session_id = session.id, user = acting_user)`  
e.g. `channels` returns all channels connecting to this session and user  
providing nil as the acting_user will test if connections can be made without there being a logged in user.

- Can a specific class connection be made:
`can_connect?(channel, user = acting_user)`
e.g. `can_connect? Todo`  returns true if current acting_user can connect to the Todo class  
You can also provide the class name as a string.

- Can a specific instance connection be made:
`can_connect?(channel, user = acting_user)`
e.g. `can_connect? Todo.first`  returns true if current acting_user can connect to the first Todo model.  
You can also provide the instance in the form 'Todo-123'

- What attributes are accessible for a model instance:  
`viewable_attributes(instance, user = acting_user)`

- Can the attribute be viewed:  
`view_permitted?(instance, attribute, user = acting_user)`

- Can a model be created/updated/destroyed:
`create_permitted?(instance, user = acting_user)`  
e.g. `create_permitted?(Todo.new, nil)` can anybody save a new todo?  
e.g. `destroy_permitted?(Todo.last)` can the acting_user destroy the last Todo

You can of course simulate server side changes to your models through this console like any other console.  For example

`Todo.new.save` will broadcast the changes to the Todo model to any authorized channels.

## Development

Specs run in rspec/capybara/selenium. To run do:

```
bundle exec rspec spec
```

You can run the specs in firefox by adding `DRIVER=ff` (best for debugging.)  You can add `SHOW_LOGS=true` if running in poltergeist (the default) to see what is going on, but ff is a lot better for debug.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/reactive-ruby/synchromesh. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
