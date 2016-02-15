require "shrine/storage/you_tube/version"

module Shrine
  module Storage
    module YouTube
      def initialize(*args)
        # initializing logic
      end

      def upload(io, id, metadata = {})
        # uploads `io` to the location `id`
      end

      def download(id)
        # downloads the file from the storage
      end

      def open(id)
        # returns the remote file as an IO-like object
      end

      def read(id)
        # returns the file contents as a string
      end

      def exists?(id)
        # checks if the file exists on the storage
      end

      def delete(id)
        # deletes the file from the storage
      end

      def url(id, options = {})
        # URL to the remote file, accepts options for customizing the URL
      end

      def clear!(confirm = nil)
        # deletes all the files in the storage
      end
    end
  end
end
