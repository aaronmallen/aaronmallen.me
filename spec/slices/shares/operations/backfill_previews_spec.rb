# frozen_string_literal: true

require "vips"

RSpec.describe Shares::Operations::BackfillPreviews do
  let(:stored) { {} }

  def backfill = Shares::Slice["operations.backfill_previews"].call

  def preview_key(file) = Shares::Slice["relations.share_group_files"].by_pk(file[:id]).one[:preview_key]

  def share(filename, content_type, key: SecureRandom.hex(16))
    Shares::Slice["repos.share_mutations"].create(
      code: Shares::Slice["repos.short_code_queries"].free_code, key:, filename:, content_type:, byte_size: 1,
    )
    Shares::Slice["relations.share_group_files"].where(key:).one
  end

  def stub_stored(file, body)
    stub_request(:get, share_store_url(file[:key])).to_return(body:, headers: { "Content-Type" => file[:content_type] })
  end

  before do
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/}).to_return do |request|
      stored[File.basename(request.uri.path)] = request.body.b
      { status: 200 }
    end
  end

  it "stores a preview for an older image and saves its key on the row", :aggregate_failures do
    image = share("wide.jpg", "image/jpeg")
    stub_stored(image, Vips::Image.black(3000, 1500).write_to_buffer(".jpg"))

    expect(backfill).to eq(1)
    expect(Vips::Image.new_from_buffer(stored.fetch(preview_key(image)), "").width)
      .to eq(Shares::Operations::StorePreview::EDGE)
  end

  it "stores nothing new the second time", :aggregate_failures do
    stub_stored(share("wide.jpg", "image/jpeg"), Vips::Image.black(300, 150).write_to_buffer(".jpg"))
    backfill

    expect(backfill).to eq(0)
    expect(stored.size).to eq(1)
  end

  it "skips a file that is not an image", :aggregate_failures do
    share("notes.txt", "text/plain")

    expect(backfill).to eq(0)
    expect(a_request(:get, /shares\.example/)).not_to have_been_made
  end

  it "leaves an image the store cannot return for the next run", :aggregate_failures do
    image = share("wide.jpg", "image/jpeg")
    stub_request(:get, share_store_url(image[:key])).to_timeout

    expect(backfill).to eq(0)
    expect(preview_key(image)).to be_nil
  end

  it "leaves an image libvips cannot read as it was", :aggregate_failures do
    image = share("broken.jpg", "image/jpeg")
    stub_stored(image, "\xFF\xD8\xFFnot a jpeg".b)

    expect(backfill).to eq(0)
    expect([preview_key(image), stored]).to eq([nil, {}])
  end
end
