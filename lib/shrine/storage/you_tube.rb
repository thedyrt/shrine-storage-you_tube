require "shrine/storage/you_tube/version"
require "google/apis/youtube_v3"

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

      def initialize(
        original_storage:,
        client_id:,
        client_secret:,
        refresh_token:,
        channel_id: nil,
        default_privacy: :private,
        upload_options: {}
      )
        @youtube = youtube_service(
          client_id: client_id,
          client_secret: client_secret,
          refresh_token: refresh_token
        )

        @channel_id = channel_id
        @default_privacy = default_privacy
        @upload_options = upload_options
        @original_storage = original_storage
      end

      extend Forwardable
      delegate [:download, :open, :read, :stream] => :original_storage

      def channel_id
        @channel_id ||= find_user_channel
      end

      def upload(io, id, metadata = {})
        snippet = { title: metadata["filename"], channel_id: channel_id }
        snippet.update(upload_options)
        snippet.update(metadata.delete("youtube") || {})

        video_data = Google::Apis::YoutubeV3::Video.new( snippet: snippet )

        uploaded_video = youtube.insert_video('snippet', video_data, upload_source: io)
        id.replace(uploaded_video.id)

        io.rewind
        original_storage.upload(io, id, metadata)

        uploaded_video.to_h
      end

      def exists?(id)
        youtube.list_videos('id', id: id).page_info.total_results == 1
      end

      def delete(id)
        youtube.delete_video(id)
        original_storage.delete(id)
      end

      def url(id, type: nil, **options)
        case type && type.to_sym
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

      def clear!(confirm = nil)
        raise Shrine::Confirm unless confirm == :confirm

        while uploads_playlist_count > 0
          uploads_playlist_items.items.each do |item|
            video_id = item.snippet.resource_id.video_id
            youtube.delete_video(video_id)
          end
        end

        original_storage.clear!(confirm)
      end

      def update(id, metadata: {})
        snippet = metadata.delete("youtube")

        if snippet
          video_query = youtube.list_videos('snippet', id: id)
          raise VideoNotFound unless video_query.page_info.total_results == 1

          existing_snippet = video_query.items.first.snippet.to_h

          video_data = Google::Apis::YoutubeV3::Video.new( id: id, snippet: existing_snippet.merge(snippet) )
          updated_video = youtube.update_video('snippet', video_data)
          updated_video.to_h
        end
      end
      
      protected

      def youtube_service(credentials)
        service = Google::Apis::YoutubeV3::YouTubeService.new
        service.authorization = Google::Auth::UserRefreshCredentials.new(credentials)
        service
      end

      def find_user_channel
        user_channels = youtube.list_channels('id', mine: true)
        channel_count = user_channels.items.count

        if channel_count == 1
          user_channels.items.first.id
        else
          raise UserChannelNotFound, channel_count
        end
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
    end
  end
end
