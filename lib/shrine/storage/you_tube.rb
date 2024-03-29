# frozen_string_literal: true

require 'shrine/storage/you_tube/version'
require 'google/apis/youtube_v3'

class Shrine
  module Storage
    class YouTube
      class UserChannelNotFound < StandardError
        def initialize(found_channel_count)
          super("Could not determine the user's channel (found #{found_channel_count} channels). Create a channel at https://www.youtube.com/create_channel or set channel_id.")
        end
      end

      class VideoNotFound < StandardError; end

      attr_reader :original_storage, :youtube, :default_privacy, :upload_options

      extend Forwardable
      def initialize(
        original_storage:,
        client_id:,
        client_secret:,
        refresh_token:,
        channel_id: nil,
        default_privacy: :private,
        upload_options: {},
        client_options: {},
        request_options: {}
      )
        @youtube = youtube_service(
          client_id: client_id,
          client_secret: client_secret,
          refresh_token: refresh_token,
          client_options: client_options,
          request_options: request_options
        )

        @channel_id = channel_id
        @default_privacy = default_privacy
        @upload_options = upload_options
        @original_storage = original_storage
      end

      delegate %i[download open read stream] => :original_storage

      def channel_id
        @channel_id ||= find_user_channel
      end

      def upload(io, id, _old_metadata = {}, shrine_metadata: {}, **passed_upload_options)
        # Shrine stopped using this _old_metadata positional argument in 2.0.0
        # which is the first version this gem supports. Unfortunately, their linter
        # didn't switch to dropping the argument until 3.2.1, so we include it here
        # for compatibility with the linter under earlier versions of Shrine.

        snippet = { title: shrine_metadata['filename'], channel_id: channel_id }
        snippet.update(upload_options)
        snippet.update(passed_upload_options)
        snippet.update(shrine_metadata.delete('youtube') || {})

        video_data = Google::Apis::YoutubeV3::Video.new(snippet: snippet)
        uploaded_video = upload_video(io, video_data)

        id.replace(uploaded_video.id)
        original_storage.upload(io, id, shrine_metadata: shrine_metadata)

        uploaded_video.to_h
      end

      def exists?(id)
        youtube.list_videos('id', id: id).page_info.total_results == 1
      end

      def delete(id)
        return unless exists?(id)

        youtube.delete_video(id)
        original_storage.delete(id)
      end

      def url(id, type: nil, **options)
        case type&.to_sym
        when :original
          original_storage.url(id, **options)
        when :embed
          "https://youtube.com/embed/#{id}"
        when :short
          "https://youtu.be/#{id}"
        else
          "https://youtube.com/watch?v=#{id}"
        end
      end

      def clear!
        while uploads_playlist_count.positive?
          uploads_playlist_items.items.each do |item|
            video_id = item.snippet.resource_id.video_id
            youtube.delete_video(video_id)
          end
        end

        original_storage.clear!
      end

      def update(id, metadata: {})
        snippet = metadata.delete('youtube')
        return unless snippet

        video_query = youtube.list_videos('snippet', id: id)
        raise VideoNotFound unless video_query.page_info.total_results == 1

        existing_snippet = video_query.items.first.snippet.to_h

        video_data = Google::Apis::YoutubeV3::Video.new(id: id, snippet: existing_snippet.merge(snippet))
        updated_video = youtube.update_video('snippet', video_data)
        updated_video.to_h
      end

      protected

      def youtube_service(client_id:, client_secret:, refresh_token:, client_options: {}, request_options: {})
        Google::Apis::YoutubeV3::YouTubeService.new.tap do |service|
          service.authorization = Google::Auth::UserRefreshCredentials.new(
            client_id: client_id,
            client_secret: client_secret,
            refresh_token: refresh_token
          )
          client_options.each { |k, v| service.client_options[k] = v }
          request_options.each { |k, v| service.request_options[k] = v }
        end
      end

      def find_user_channel
        user_channels = youtube.list_channels('id', mine: true)
        channel_count = user_channels.items.count

        raise(UserChannelNotFound, channel_count) unless channel_count == 1

        user_channels.items.first.id
      end

      def uploads_playlist_id
        @uploads_playlist_id ||= begin
          channel_response = youtube.list_channels('contentDetails', id: channel_id)
          channel = channel_response.items.first
          channel.content_details.related_playlists.uploads
        end
      end

      def uploads_playlist_items
        youtube.list_playlist_items('snippet', playlist_id: uploads_playlist_id)
      end

      def uploads_playlist_count
        uploads_playlist_items.page_info.total_results
      end

      def upload_video(io, video_data)
        youtube.insert_video('snippet', video_data, upload_source: io)
      rescue Google::Apis::ClientError => e
        raise e unless (
          e.message.include?('mediaBodyRequired') ||
          e.message.include?('invalidFilename') ||
          e.message.include?('Invalid upload source')
        ) && io.respond_to?(:download)

        io.download do |tempfile|
          youtube.insert_video('snippet', video_data, upload_source: tempfile)
        end
      ensure
        io.rewind
      end
    end
  end
end
