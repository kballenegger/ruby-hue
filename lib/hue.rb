
require 'curb'
require 'upnp/ssdp'
require 'nokogiri'

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
  end

  def ip
    @ip
  end
end
