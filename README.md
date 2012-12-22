# Hue

`ruby-hue` is a simple Ruby library and binary for manipulating the Philips Hue
lighting system.


## Examples

(In a `pry` shell... for awesomeness)

```ruby
require 'hue'
h = Hue::Hue.new # make use of auto-discovery

h.poll_state # fetch and print system status

h.set_bright_color(1, Color::RGB::Red)

h.all_lights.write bri: 255, hue: 40000, sat: 200

# alternate between blue and red
(1..1.0/0).each do |n|
  h.all_lights.write hue: n.even? ? 0 : 248 * 182, transitiontime: 1
  sleep 0.15
end
```


## Documentation

It is highly recommended that you read the inline comments in `lib/hue.rb`. The
module is very thoroughly documented.


## Installation & Requirements

Make sure you have the following packages installed (including devel versions):

    libcurl, libxml

You're also going to need to install the `upnp` gem. Unfortunately it is not yet released publicly, so I have included it here as a submodule dependency. The easiest way to get setup right now would be:

```bash
git clone $repo
git submodule init
git submodule update
cd httpi && bundle install && rake install && cd ..
cd upnp && bundle install && rake install && cd ..
bundle install
rake install
```

`gem install ruby-hue` will only work when `upnp` has been successfully installed.


## Credit

Thanks to this link for figuring out most of the unofficial Hue REST API:

http://rsmck.co.uk/hue
