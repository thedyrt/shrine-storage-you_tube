require 'spec_helper'
require 'shrine/storage/linter'

describe Shrine::Storage::YouTube, :vcr do
  let(:video) { File.open(File.expand_path('../../../upload/blank.mp4', __FILE__)) }

  let(:video_content) do
    begin
      video.read
    ensure
      video.rewind
    end
  end

  let(:downloaded_video) do
    tmp = Tempfile.new('video')
    tmp.write video_content
    tmp.rewind
    tmp
  end

  let(:original_storage) { double(
    upload: true,
    download: downloaded_video,
    read: video_content,
    open: video,
    delete: true,
    clear!: true
  )}

  before { allow(original_storage).to receive(:stream).and_yield(video_content) }

  let(:minimum_options) do
    {
      original_storage: original_storage,
      client_id: ENV['GOOGLE_OAUTH_CLIENT_ID'] || "abc",
      client_secret: ENV['GOOGLE_OAUTH_CLIENT_SECRET'] || "def",
      refresh_token: ENV['GOOGLE_OAUTH_REFRESH_TOKEN'] || "hij"
    }
  end

  let(:options) { minimum_options }
  let(:youtube_storage) { described_class.new(options) }

  it "passes the linter" do
    Shrine::Storage::Linter.new(youtube_storage).call(->{video})
  end

  describe "#initialize" do
    REQUIRED_ATTRIBUTES = %i(original_storage client_id client_secret refresh_token)
    OPTIONAL_ATTRIBUTES = %i(channel_id default_privacy upload_options)

    it "initializes with valid options" do
      expect { youtube_storage }.to_not raise_exception
    end

    it "looks up the user's channel_id" do
      expect(youtube_storage.channel_id).to_not be_nil
    end

    REQUIRED_ATTRIBUTES.each do |key|
      context "without require attribute '#{key}'" do
        let(:options) { minimum_options.delete(key) && minimum_options }

        it "fails to initialize" do
          expect { youtube_storage }.to raise_exception(ArgumentError)
        end
      end
    end

    OPTIONAL_ATTRIBUTES.each do |key|
      context "with optional attribute '#{key}'" do
        let(:option_value) { double }
        let(:options) { minimum_options.merge(key => option_value) }

        it "exposes #{key} on the instance" do
          expect(youtube_storage.send(key)).to eq option_value
        end
      end
    end
  end

  describe "#original_storage" do
    FORWARDED_METHODS = %i(download open read stream)

    it "exposes the original storage" do
      expect(youtube_storage.original_storage).to eq original_storage
    end

    FORWARDED_METHODS.each do |method|
      before { allow(original_storage).to receive(method) }

      it "forwards ##{method} to the original storage" do
        youtube_storage.send(method)
        expect(original_storage).to have_received(method)
      end
    end
  end

  describe "#upload" do
    let(:metadata) { Hash.new }
    let(:upload_result) { youtube_storage.upload(video, "original_id", metadata) }

    it "uploads the video to YouTube and replaces the ID" do
      expect(upload_result[:id]).to_not be_nil
      expect(upload_result[:id]).to_not eq "original_id"
    end

    context "with 'filename' in metadata" do
      let(:metadata) {{ 'filename' => 'hello.mp4' }}

      it "sets the title based on 'filename' metadata'" do
        expect(upload_result[:snippet][:title]).to eq "hello.mp4"
      end

      context "with 'youtube' in metadata" do
        let(:metadata) {{ 
          'filename' => 'hello.mp4',
          'youtube' => {
            title: "Good Morning",
            description: "Howdy"
          }
        }}

        it "uses metadata['youtube'] to set the YouTube snippet" do
          expect(upload_result[:snippet][:title]).to eq "Good Morning"
          expect(upload_result[:snippet][:description]).to eq "Howdy"
        end
      end
    end

    context "with upload_options set" do
      let(:options) { minimum_options.merge(
        upload_options: {
          title: "Good Morning",
          description: "Howdy"
        }
      )}

      it "uses upload_options to set the YouTube snippet" do
        expect(upload_result[:snippet][:title]).to eq "Good Morning"
        expect(upload_result[:snippet][:description]).to eq "Howdy"
      end
    end

    it "uploads to the original storage with the YouTube ID" do
      youtube_id = upload_result[:id]
      expect(original_storage).to have_received(:upload).with(video, youtube_id, {})
    end
  end

  describe "#exists?" do
    context "for a non-existant video" do
      it "does not find a video" do
        expect(youtube_storage.exists?("bad_id")).to be false
      end
    end

    context "after a video has been uploaded" do
      let(:upload_result) { youtube_storage.upload(video, "original_id", {}) }
      let(:video_id) { upload_result[:id] }

      it "finds the uploaded video" do
        expect(youtube_storage.exists?(video_id)).to be true
      end
    end
  end

  describe "#delete" do
    let(:upload_result) { youtube_storage.upload(video, "original_id", {}) }
    let(:video_id) { upload_result[:id] }

    it "deletes uploaded videos by ID" do
      expect(youtube_storage.exists?(video_id)).to be true
      youtube_storage.delete(video_id)
      expect(youtube_storage.exists?(video_id)).to be false
    end

    it "deletes from the original storage" do
      youtube_storage.delete(video_id)
      expect(original_storage).to have_received(:delete).with(video_id)
    end
  end

  describe "#url" do
    before { allow(original_storage).to receive(:url) }

    it "asks the original storage when type: original" do
      youtube_storage.url("id", type: :original)
      expect(original_storage).to have_received :url
    end

    it "generates embed URLs" do
      expect(youtube_storage.url("id", type: :embed)).to eq "https://youtube.com/embed/id"
    end

    it "generates short URLs" do
      expect(youtube_storage.url("id", type: :short)).to eq "https://youtu.be/id"
    end

    it "generates long URLs by default" do
      expect(youtube_storage.url("id")).to eq "https://youtube.com/watch?v=id"
    end
  end

  describe "#clear!" do
    let(:first_upload_result) { youtube_storage.upload(video, "original_id", {}) }
    let(:second_upload_result) { youtube_storage.upload(video, "original_id", {}) }
    let(:video_ids) { [first_upload_result[:id], second_upload_result[:id]] }

    context "without confirmation" do
      it "requires confirmation" do
        expect{ youtube_storage.clear! }.to raise_exception(Shrine::Confirm)
      end

      it "does not delete the uploaded videos" do
        begin
          youtube_storage.clear!
        rescue Shrine::Confirm
        end

        video_ids.each do |id|
          expect(youtube_storage.exists?(id)).to be true
        end

        expect(original_storage).to_not have_received(:clear!)
      end

      context "with confimation" do
        it "deletes all videos from the channel and clears the original storage" do
          video_ids
          youtube_storage.clear!(:confirm)

          video_ids.each do |id|
            expect(youtube_storage.exists?(id)).to be false
          end

          expect(original_storage).to have_received(:clear!).with(:confirm)
        end
      end
    end
  end

  describe "#update" do
    let(:upload_result) { youtube_storage.upload(video, "original_id", {}) }
    let(:video_id) { upload_result[:id] }
    let(:metadata) {{ 
      'youtube' => {
        title: "Good Morning",
        description: "Howdy"
      }
    }}

    let(:update_result) { youtube_storage.update(video_id, metadata: metadata) }

    it "updates existing metadata" do
      expect(update_result[:snippet][:title]).to eq "Good Morning"
      expect(update_result[:snippet][:description]).to eq "Howdy"
    end
  end
end
