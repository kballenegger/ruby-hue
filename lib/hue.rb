
require 'curb'
require 'upnp/ssdp'
require 'nokogiri'
require 'json'
require 'digest/sha1'
require 'color'

class Hue

  def self.discover_ip
    UPnP::SSDP.log = false # get rid of this pesky debug logging!
    services = UPnP::SSDP.search('urn:schemas-upnp-org:device:basic:1').map {|s| s[:location] }
    valid_location = services.find do |l|
      xml = Curl.get(l).body_str
      doc = Nokogiri::XML(xml)
      name = doc.css('friendlyName').first
      return false unless name
      name.text =~ /^Philips hue/
    end
    raise unless valid_location
    /(([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])/.match(valid_location)[0]
  end
  
  def initialize(opts = {})
    @ip = opts[:ip] || self.class.discover_ip
    @client = opts[:client] || 'ruby-hue'
    @username = opts[:username] || Digest::SHA1.hexdigest(`hostname`.strip)
  end

  def request(method, path, body = {})
    url = "http://#{@ip}/api/#{@username}#{path}"
    _request(method, url, body)
  end

  def _request(method, url, body = {})
    body_str = body.to_json
    case method
    when :get
      r = Curl.get(url)
    when :post
      r = Curl.post(url, body.to_json)
    when :put
      r = Curl.put(url, body.to_json)
    else
      raise
    end
    JSON.parse(r.body_str)
  end

  def authorize
    _request(:post, "http://#{@ip}/api/", :devicetype => @client, :username => @username)
  end

  def poll_state
    state = request(:get, '/')
    raise unless state['lights'] # poor man's way of checking for success
    @state = state
  end

  def lights
    @state['lights']
  end

  def each_light
    lights.each {|k,v| yield k }
    nil
  end

  def wait_for_rate_limit
    @last_request_times ||= []
    while @last_request_times.count > 25
      @last_request_times.select! {|t| Time.now - t < 1 }
      sleep 0.1
    end
    @last_request_times << Time.now
  end

  def write(light, state)
    wait_for_rate_limit
    request(:put, "/lights/#{light}/state", state)
  end

  def off(light)
    write(light, :on => false)
  end

  def on(light)
    write(light, :on => true)
  end

  def cycle_thru_colors(sleep_between_steps = 1)
    (0..65535).step(5000).each {|n| self.each_light {|id| self.write(id, :hue => n) }; sleep sleep_between_steps } while true
  end

  # color should be a color object from the color gem
  # it must implement to_hsl, which must return something that implements .h,
  # .l, and .s.
  def set_color(light, color)
    hsl = color.to_hsl
    write(light, bri: (hsl.l * 255).to_i, sat: (hsl.s * 255).to_i, hue: (hsl.h * 182).to_i)
  end
end
