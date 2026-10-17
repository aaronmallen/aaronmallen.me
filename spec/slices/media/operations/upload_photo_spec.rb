# frozen_string_literal: true

require "vips"

RSpec.describe Media::Operations::UploadPhoto do
  let(:store) do
    Class.new do
      attr_reader :objects, :puts, :rows

      def initialize(fail_on:)
        @fail_on = fail_on
        @objects = {}
        @puts = 0
        @rows = []
      end

      def configured? = true

      def discard(keys) = keys.each { objects.delete(it) }

      def put(key, body, **)
        @puts += 1
        @rows << Media::Slice["relations.photos"].count
        raise ObjectStore::Client::Error, "down" if @puts == @fail_on

        objects[key] = body
        key
      end
    end.new(fail_on:)
  end
  let(:fail_on) { 3 }

  def photos = Media::Slice["relations.photos"].to_a

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
    expect(photos).to be_empty
  end

  context "with a store that takes every put" do
    let(:fail_on) { nil }

    it "puts every object before it inserts the row", :aggregate_failures do
      expect(upload).to be_success
      expect(store.rows).to eq([0, 0, 0])
    end

    it "removes every object it stored when the insert fails", :aggregate_failures do
      allow(ObjectStore::Key).to receive(:generate).and_return("not-a-key")

      expect { upload }.to raise_error(ROM::SQL::Error)
      expect(store.puts).to eq(3)
      expect(store.objects).to be_empty
    end
  end
end
