# Shrine::YouTube

Provides [YouTube](https://youtube.com) storage for [Shrine](http://shrinerb.com).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'shrine-storage-you_tube'
```

## Usage

Since YouTube's API doesn't allow reading of uploaded data, the YouTube storage must be paired with another storage provider to hold the original videos. Videos are first uploaded to YouTube and then to the specified storage provider using the ID returned from the YouTube upload.

```ruby
require "shrine/storage/you_tube"
require "shrine/storage/s3"

s3 = Shrine::Storage::S3.new(**s3_options)
youtube = Shrine::Storage::YouTube.new(
  original_storage: s3,
  client_id: "abc123", # Google OAuth2 Client ID
  client_secret: "def456", # Google OAuth2 Client Secret
  refresh_token: "ghi789", # Refresh token for YouTube user
  # optional parameters
  channel_id: nil, # Channel ID for uploads, defaults to the user's channel
  default_privacy: :private, # one of :private, :public, or :unlisted
  upload_options: {} # may be used to set YouTube's snippet
  client_options: {} # confgure the Google API client's ClientOptions
  request_options: {} # confgure the Google API client's RequestOptions
)

Shrine.storages[:store] = youtube
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).
