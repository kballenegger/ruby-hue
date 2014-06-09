
require 'curb'
require 'playful/ssdp'
require 'nokogiri'
require 'json'
require 'digest/sha1'
require 'color'


module Hue

  # Hue is a class that can interact with and control a Philips Hue base station.
  #
  class Hue


    # Hue.discover_ip is a convenience class method that will scan the network
    # and attempt to find the Philips base station. It may take ~5s to execute.
    #
    def self.discover_ip
      playful::SSDP.log = false # get rid of this pesky debug logging!
      services = playful::SSDP.search('urn:schemas-upnp-org:device:basic:1').map {|s| s[:location] }
      valid_location = services.find do |l|
        xml = Curl.get(l).body_str
        doc = Nokogiri::XML(xml)
        name = doc.css('friendlyName').first
        return false unless name
        name.text =~ /^Philips hue/
      end
      raise 'no hue found on this network' unless valid_location
      /(([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])/.match(valid_location)[0]
    end


    # Hue can be initialized with a Hash of options.
    #
    # - opts[:ip]         should contain the IP of the base station
    #                     by default, Hue will use discover_ip to attempt to find it.
    #
    # - opts[:client]     is a User-Agent-like string, describing this client.
    #                     defaults to 'ruby-hue'
    #
    # - opts[:username]   is a hex secret string used for authentication
    #                     defaults to the SHA1 hex digest of the hostname 
    #
    def initialize(opts = {})
      @ip = opts[:ip] || self.class.discover_ip
      @client = opts[:client] || 'ruby-hue'
      @username = opts[:username] || Digest::SHA1.hexdigest(`hostname`.strip)
    end


    # Hue#request is makes an authorized request to the Hue backend, relative to
    # the url `http://@ip/api/@user`. Include any leading slashes.
    #
    # This method is mostly used internally, but made avaiable publicly for shits
    # and giggles.
    #
    def request(method, path, body = {})
      url = "http://#{@ip}/api/#{@username}#{path}"
      _request(method, url, body)
    end


    # Hue#authorize authorizes this client (@client + @username combination) with
    # the base station forever. It's a one-time operation.
    #
    # #authorize requires manual interation: the method must be called, after
    # which somebody must *physically* press the button on the base station.
    # Once that is done, the method must be called again and, this time,
    # a success confirmation message will be returned. 
    #
    def authorize
      _request(:post, "http://#{@ip}/api/", devicetype: @client, username: @username)
    end


    # Hue#poll_state returns the entire state of the system.
    #
    def poll_state
      state = request(:get, '/')
      raise unless state['lights'] # poor man's way of checking for success
      @state = state
    end


    # Hue#lights returns lights from the cached state, from the poll_state method
    # above. The state of the light themselves is only as current as the last
    # poll_state method call.
    #
    def lights
      poll_state unless @state
      @state['lights']
    end


    # Like Enum's `each`, Hue#each_light takes a block which is called for each
    # light *id*. For example:
    #
    #   hue.each_light do |l|
    #     hue.set_bright_color(l, Color::RGB::Blue)
    #   end
    #
    def each_light
      lights.each {|k,v| yield k }
      nil
    end


    # Hue#all_lights is awesome. It returns a `HueAllLightsProxy` object, which
    # is a simple object that will forward any method calls it gets to this
    # instance of Hue, once for each light, inserting the light id as the first
    # argument.
    #
    # Imagine we had the following variables:
    #
    #   hue = Hue.new
    #   proxy = hue.all_lights
    #
    # The following method call:
    #
    #   proxy.write hue: 0, bri: 200
    #
    # Would essentially be translated to these three method calls (for 3 lights):
    #
    #   hue.write 1, hue: 0, bri: 200
    #   hue.write 2, hue: 0, bri: 200
    #   hue.write 3, hue: 0, bri: 200
    #
    # ---
    #
    # Typically, you would simply use this inline, like this:
    #
    #   hue.all_lights.set_bright_color(Color::RGB::Blue)
    #
    def all_lights
      HueAllLightsProxy.new(self)
    end


    # Hue#write is the meat of what Hue is all about. This is the method that
    # writes a state change to a Hue bulb.
    #
    # In order to avoid being rate limited at the HTTP api level, this method
    # implements its own rate limiting in which it will block and wait for enough
    # time to elapse when messages are fired too quickly.
    #
    # State is an object which typically contains a combination of these keys:
    #
    #   :hue            => this is a hue value in the range (0..65535)
    #                      can be derived from (degrees * 182)
    #   :bri            => "brightness" in the range (0..255)
    #   :sat            => "saturation" in the range (0..255)
    #   :alert          => when set, triggers alert behavior. options:
    #                      :select
    #                         triggers a flash to the given color, instead of
    #                         a permanent change, when set to `true`
    #                      :lselect
    #                         same as above, except this is a constant flashing,
    #                         insead of a one time trigger
    #   :transitiontime => an Integer representing the "transition time," ie. the
    #                      amount of time over which the color fade will occur.
    #                      this is measured in tenths of seconds. a value of
    #                      0 means a hard switch, no fade. defaulys to ~5-ish
    #
    def write(light, state)
      wait_for_rate_limit
      request(:put, "/lights/#{light}/state", state)
    end


    # Hue#off turns off the specified light.
    #
    def off(light)
      write(light, on: false)
    end


    # Hue#on turns on the specified light.
    #
    def on(light)
      write(light, on: true)
    end


    # Hue#set_color sets a light to a specified color.
    #
    # set_color expects color to be a color object from the `color` gem, or
    # something that implements its interface:
    # 
    # color must implement to_hsl, which must return an object that implements
    # .h, .l, and .s. These methods are expected to return floats in (0.0..1.1)
    #
    def set_color(light, color, opts={})
      hsl = color.to_hsl
      opts = opts.merge(bri: (hsl.l * 255).to_i,
                        sat: (hsl.s * 255).to_i,
                        hue: (hsl.h * 360 * 182).to_i)
      write(light, opts)
    end


    # Hue#set_bright_color is often more useful than its `set_color`
    # counterpart, because when converting RGB colors to HSL, a color might not
    # be expected to have full brightness. But with a known hue & saturation,
    # it's often desirable to have full brightness. This method uses `bri: 255`
    #
    def set_bright_color(light, color, opts={})
      color = color.to_hsl
      color.l = 1
      set_color(light, color, opts)
    end


    # Hue#preset returns a HuePresetsProxy object, which is meant to be used
    # much like Hue#all_lights. For example:
    #
    #   hue.preset.cycle_thru_colors
    #
    def preset
      HuePresetsProxy.new(self)
    end






    private

    def wait_for_rate_limit
      @last_request_times ||= []
      while @last_request_times.count > 25
        @last_request_times.select! {|t| Time.now - t < 1 }
        sleep 0.1
      end
      @last_request_times << Time.now
    end

    def _request(method, url, body = {})
      body_str = body.to_json

      case method
      when :get
        r = Curl.get(url) do |r|
                r.timeout = 2
        end
      when :post
        r = Curl.post(url, body.to_json) do |r|
                r.timeout = 2
        end
      when :put
        r = Curl.put(url, body.to_json) do |r|
                r.timeout = 2
        end
      else
        raise
      end
      JSON.parse(r.body_str)
    end



  end


  # Presets is a module which contains neat helper functions that are part of
  # the basic interface for interaction with Hue, but which uses Hue to create
  # some very neat effects.
  #
  module Presets

    def self.cycle_thru_color_arr(hue, colors, sleep_between_steps = 1)
      colors = colors.dup
      loop do
        hue.each_light {|l| hue.set_bright_color(l, colors.first)}
        colors << colors.shift
        sleep sleep_between_steps
      end
    end

    def self.cycle_thru_colors(hue, sleep_between_steps = 1)
      (0..65535).step(5000).each do |n|
        hue.all_lights.write(hue: n); sleep sleep_between_steps 
      end while true
    end

    # --- even more specific

    def self.police_lights(hue)
      colors = [Color::RGB::Blue, Color::RGB::Red]
      loop do
        hue.all_lights.set_bright_color(colors.first, transitiontime: 0)
        colors << colors.shift
        sleep 0.1
      end
    end

    def self.strobe(hue)
      hue.all_lights.write bri: 0
      loop do
        hue.all_lights.write(bri: 255,
                             alert: :select,
                             transitiontime: 0)
      end
    end
  end






  private

  class HueAllLightsProxy
    def method_missing(method, *args)
      @h.each_light {|l| @h.send(method, l, *args) }
    end

    def initialize(hue)
      @h = hue
    end

    def methods
      @h.methods
    end
  end

  class HuePresetsProxy
    def method_missing(method, *args)
      Presets.send(method, @h, *args)
    end

    def initialize(hue)
      @h = hue
    end

    def methods
      Presets.methods
    end
  end

end
