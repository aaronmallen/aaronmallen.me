# frozen_string_literal: true

require "vips"

RSpec.describe Media::Operations::UploadPhoto do
  let(:store) do
    Class.new do
      attr_reader :objects, :puts

      def initialize(fail_on:)
        @fail_on = fail_on
        @objects = {}
        @puts = 0
      end

      def configured? = true

      def delete(key) = objects.delete(key) && nil

      def put(key, body, **)
        @puts += 1
        raise ObjectStore::Client::Error, "down" if @puts == @fail_on

        objects[key] = body
        key
      end
    end.new(fail_on: 3)
  end

  def upload
    bytes = Vips::Image.black(1500, 750).write_to_buffer(".png")
    file = Blog::Types::UploadParam[tempfile: StringIO.new(bytes), filename: "a.png"]
    Media::Slice["operations.upload_photo"].call(file)
  end

  before { replace_component("media_store.client", store) }

  it "removes the objects it stored when a later put fails", :aggregate_failures do
    expect(upload.failure).to eq([:unavailable])
    expect(store.puts).to eq(3)
    expect(store.objects).to be_empty
    expect(Media::Slice["relations.photos"].to_a).to be_empty
  end
end
