# frozen_string_literal: true

require "vips"

RSpec.describe Media::Operations::BackfillPhotoWidths do
  let(:put) { {} }

  def backfill = Media::Slice["operations.backfill_photo_widths"].call

  def stub_stored(photo, width)
    body = Vips::Image.black(width, width / 2).write_to_buffer(".jpg")
    stub_request(:get, media_store_url(photo.key)).to_return(body:, headers: { "Content-Type" => "image/jpeg" })
  end

  def widths(photo) = Media::Slice["relations.photos"].by_pk(photo.id).one[:widths]

  before do
    connect_media_store
    stub_request(:put, %r{store\.example.*/\d+/}).to_return do |request|
      put[request.uri.path[%r{/(\d+)/}, 1].to_i] = Vips::Image.new_from_buffer(request.body.b, "").width
      { status: 200 }
    end
  end

  it "stores each smaller width of an older photo and lists them on its row", :aggregate_failures do
    photo = create(:photo, width: 1500, height: 750)
    stub_stored(photo, 1500)

    expect(backfill).to eq(1)
    expect(put).to eq(640 => 640, 1280 => 1280)
    expect(widths(photo)).to eq([640, 1280])
  end

  it "skips a photo that already lists its widths or is too narrow for any", :aggregate_failures do
    create(:photo, width: 1500, height: 750, widths: [640, 1280])
    create(:photo, width: 640, height: 480)

    expect(backfill).to eq(0)
    expect(a_request(:get, /store\.example/)).not_to have_been_made
  end

  it "leaves a photo the store cannot return for the next run", :aggregate_failures do
    photo = create(:photo, width: 1500, height: 750)
    stub_request(:get, media_store_url(photo.key)).to_timeout

    expect(backfill).to eq(0)
    expect(widths(photo)).to eq([])
  end
end
