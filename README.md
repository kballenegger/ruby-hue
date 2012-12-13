# Hue

`ruby-hue` is a simple Ruby library and binary for manipulating the Philips Hue lighting system.

## Examples

(In a `pry` shell... for awesomeness)

```ruby
require 'hue'
h = Hue.new # make use of auto-discovery

h.poll_state # fetch and print system status

h.set_bright_color(Color::RGB::Red)

h.all_lights.write bri: 255, hue: 40000, sat: 200

# switch between blue and red
(1..1.0/0).each {|n| h.each_light {|l| h.write l, hue: n.even? ? 0 : 248 * 182, transitiontime: 1 }; sleep 0.15 }

```

## Credit

Thanks to this link for figuring out most of the unofficial Hue REST API:

http://rsmck.co.uk/hue
