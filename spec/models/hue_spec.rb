require 'spec_helper'

require 'hue'

describe Hue::Hue do
  
  describe "when managing the IP address" do
    
    let(:yml_file_data) {':ip: 192.168.0.3'}
    
    it "should not the read the IP address from cache if the config file does not exist" do
      File.stub(:exists?).and_return(false)
      File.should_not_receive(:open)
      
      Hue::Hue.ip_from_cache.should be_nil
    end
    
    it "should the read the IP address from cache if the config file does exist" do
      File.stub(:exists?).and_return(true)
      File.stub(:read) { StringIO.new(yml_file_data) }
      
      Hue::Hue.ip_from_cache.should == '192.168.0.3'
    end
    
    it "should the write the IP address to cache" do
      file = mock('file')
      File.should_receive(:open).and_yield(file)
      file.should_receive(:write).with("--- \n:ip: 192.168.0.4\n")
      
      Hue::Hue.ip_to_cache('192.168.0.4')
    end
  end
  
  describe "when we are not managing the IP address" do
    before(:each) do
      success_json = [{"success"=>{"/lights"=>true}}].to_json
      stub_request(:any, /^http:\/\/(\d+\.?){4}\/.*/).to_return(:body => success_json)
    
      Hue::Hue.stub(:ip_from_cache).and_return(nil)
      Hue::Hue.stub(:discover_ip).and_return("192.168.0.1")
    end
  
    it "should call :discover_ip" do
      Hue::Hue.should_receive(:discover_ip)
    
      Hue::Hue.new
    end
  
    it "should not call :discover_ip if IP is loaded from config file" do
      Hue::Hue.stub(:ip_from_cache).and_return("192.168.0.1")
      Hue::Hue.should_not_receive(:discover_ip)
    
      Hue::Hue.new
    end
  
    it "should not call :discover_ip if :ip is provided" do
      Hue::Hue.should_not_receive(:discover_ip)
    
      Hue::Hue.new(ip: "192.168.0.2")
    end
  
    it "should call :hexdigest" do
      Digest::SHA1.should_receive(:hexdigest)
    
      Hue::Hue.new
    end
  
    it "should not call :hexdigest if :username is provided" do
      Digest::SHA1.should_not_receive(:hexdigest)
    
      Hue::Hue.new(username: "some_random_hex")
    end

  

    describe "when requesting the hue API" do
    
      let(:hue) { Hue::Hue.new }
    
      it "polls light" do
        lights_json = {"lights" => {}}.to_json
        stub_request(:get, /^http:\/\/(\d+\.?){4}\/.*/).to_return(:body => lights_json)
      
        hue.poll_state
      
        a_request(:get, /.*\/$/).should have_been_made
      end
    
      it "raises an error if :lights params is not present" do
        expect {
          hue.poll_state
        }.to raise_error
      end

      it "switching on" do
        hue.on(1)
      
        a_request(:put, /.*lights\/\d\/state.*/).with(:body => {"on" => true}.to_json).should have_been_made
      end
    
      it "switching off" do
        hue.off(1)
      
        a_request(:put, /.*lights\/\d\/state.*/).with(:body => {"on" => false}.to_json).should have_been_made
      end
    
      it "setting a color" do
        hue.set_color(1, Color::RGB::Red)
      
        a_request(:put, /.*lights\/\d\/state.*/).with(:body => {"bri" => 127, "sat" => 255, "hue" => 0}.to_json).should have_been_made
      end
    
      it "setting a bright color" do
        hue.set_bright_color(1, Color::RGB::Red)
      
        a_request(:put, /.*lights\/\d\/state.*/).with(:body => {"bri" => 255, "sat" => 255, "hue" => 0}.to_json).should have_been_made
      end
    
      it "setting a color" do
        hue.set_color(1, Color::RGB::Red, {"on" => true})
      
        a_request(:put, /.*lights\/\d\/state.*/).with(:body => {"on" => true, "bri" => 127, "sat" => 255, "hue" => 0}.to_json).should have_been_made
      end
    end
  end
  
  
end