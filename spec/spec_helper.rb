# frozen_string_literal: true

require 'dotenv'
Dotenv.load

require 'cgi'
require 'vcr'
require 'webmock/rspec'

begin
  require 'zlib'
  require 'stringio'
  have_zlib = true
rescue LoadError
  have_zlib = false
end

VCR.configure do |c|
  c.hook_into :webmock
  c.cassette_library_dir = 'spec/cassettes'

  c.filter_sensitive_data('<CLIENT_ID>') { ENV['GOOGLE_OAUTH_CLIENT_ID'] || 'abc' }
  c.filter_sensitive_data('<CLIENT_SECRET>') { ENV['GOOGLE_OAUTH_CLIENT_SECRET'] || 'def' }
  c.filter_sensitive_data('<REFRESH_TOKEN>') { CGI.escape ENV['GOOGLE_OAUTH_REFRESH_TOKEN'] || 'hij' }
  c.filter_sensitive_data('<ACCESS_TOKEN>') do |interaction|
    parsed = begin
               JSON.parse(interaction.response.body)
             rescue StandardError
               {}
             end
    parsed['access_token']
  end
  c.filter_sensitive_data('<BEARER_TOKEN>') do |interaction|
    auth_headers = interaction.request.headers['Authorization'] || []
    auth_header = auth_headers.first || ''
    auth_header[7..-1] if auth_header.include? 'Bearer'
  end

  c.preserve_exact_body_bytes do |http_message|
    http_message.body.encoding.name == 'ASCII-8BIT' ||
      !http_message.body.valid_encoding?
  end

  c.before_record do |i|
    if have_zlib && (enc = i.response.headers['Content-Encoding']) && (Array(enc).first == 'gzip')
      begin
        i.response.body = Zlib::GzipReader.new(StringIO.new(i.response.body), encoding: 'ASCII-8BIT').read
        i.response.update_content_length_header
        i.response.headers.delete 'Content-Encoding'
      rescue Zlib::GzipFile::Error # rubocop:disable Lint/HandleExceptions
        # let things through as-is
      end
    end
  end

  c.configure_rspec_metadata!
end

RSpec.configure do |c|
  c.filter_run focus: true
  c.run_all_when_everything_filtered = true
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'shrine/storage/you_tube'
