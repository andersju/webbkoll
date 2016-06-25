require 'optparse'
require 'ostruct'
require 'faraday'
require 'json'
require 'public_suffix'
require 'uri'
require 'nokogiri'
require 'addressable/uri'

module Webbkoll 
  def self.fetch(url, options)
    backend_url = options.backend_url || 'http://localhost:8100/'

    conn = Faraday.new(backend_url, request: { open_timeout: 5, timeout: 20 })
    response = conn.get '/', { :fetch_url => url,
                               :get_requests => "true",
                               :get_cookies => "true",
                               :parse_delay => 10000,
                               :force => options.force }
    return response.body
  end

  def self.process_json(json)
    json = JSON.parse(json)

    unless json['success']
      raise StandardError, json['reason']
    end

    data = {}
    data['cookies'] = {}
    data['cookies']['first_party'] = []
    data['cookies']['third_party'] = []
    data['third_party_requests'] = []
    data['headers'] = {}

    url = Addressable::URI.parse(json['final_url'])
    # Needed to distinguish between first-party and third-party cookies
    begin
      host = PublicSuffix.parse(url.host)
      registerable_domain = "#{host.sld}.#{host.tld}"
    rescue PublicSuffix::DomainNotAllowed # For sites like gov.uk
      registerable_domain = url.host
    end

    data['input_url'] = json['input_url']
    data['final_url'] = json['final_url']
    data['scheme']    = url.scheme

    json['cookies'].each do |cookie|
      if cookie['domain'].end_with?(registerable_domain)
        data['cookies']['first_party'] << cookie
      else
        data['cookies']['third_party'] << cookie
      end
    end

    json['requests'].each do |req|
      req_host = Addressable::URI.parse(req['url']).host # TODO: hantera trasiga URL:er!
      unless req_host.nil?
        unless req_host.end_with?(registerable_domain)
          data['third_party_requests'] << req['url']
        end
      end
    end

    doc = Nokogiri::HTML(json['content'])
    data['meta_referrer_policy'] = doc.at("meta[name='referrer']")['content'] if doc.at("meta[name='referrer']")

    data['headers']['strict-transport-security']           = json['response_headers']['strict-transport-security'] || nil
    data['headers']['content-security-policy']             = json['response_headers']['content-security-policy'] || nil
    data['headers']['content-security-policy-report-only'] = json['response_headers']['content-security-policy-report-only'] || nil
    data['headers']['public-key-pins']        		   = json['response_headers']['public-key-pins'] || nil
    data['headers']['x-frame-options']          	   = json['response_headers']['x-frame-options'] || nil
    data['headers']['x-xss-protection']       		   = json['response_headers']['x-xss-protection'] || nil
    data['headers']['x-content-type-options'] 		   = json['response_headers']['x-content-type-options'] || nil

    return JSON.pretty_generate(data)
  end
end

options = OpenStruct.new
OptionParser.new do |opts|
  opts.banner = "Usage: webbkoll.rb [options] <URL>"
  opts.on('-b', '--backend-url=URL', 'Backend URL (default: http://localhost:9100)') { |o| options.backend_url = o }
  opts.on('-f', '--force', 'Force a cache refresh') { |o| options.force = o }
  opts.on('-o', '--output=FILE', 'Write output to specified file. Default is STDOUT.') { |o| options.output = o }
end.parse!

if ARGV.empty?
    puts "URL missing."
else
  url = ARGV[0]
end

begin
  response_body = Webbkoll.fetch(url, options)
rescue Faraday::Error => e
  puts e.to_s
end

begin
  json = Webbkoll.process_json(response_body)
rescue JSON::ParserError
  puts e.to_s
end

if options.output
  File.open(options.output, 'w') { |file| file.write(json) }
else
  puts json
end
