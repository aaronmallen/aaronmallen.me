# frozen_string_literal: true

require "vips"

RSpec.describe Shares::Operations::DeleteShare do
  let(:share) { upload_share.value! }

  def delete(id = share.id) = described_class.new.call(id)

  def rows(name) = Shares::Slice["relations.#{name}"].count

  before do
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
    stub_request(:delete, %r{\A#{share_store_url}/})
  end

  it "removes the row, its code and its object from the shares bucket", :aggregate_failures do
    expect(delete).to be_success
    expect(rows(:shares)).to eq(0)
    expect(rows(:short_codes)).to eq(0)
    expect(a_request(:delete, share_store_url(share.key))).to have_been_made
    expect(a_request(:any, /store\.example/)).not_to have_been_made
  end

  it "removes the image's preview from the bucket too" do
    image = upload_share(Vips::Image.black(30, 30).write_to_buffer(".png"), "dot.png", "image/png").value!
    delete(image.id)

    expect(a_request(:delete, share_store_url(image.preview_key))).to have_been_made
  end

  it "keeps the share when the store fails", :aggregate_failures do
    stub_request(:delete, share_store_url(share.key)).to_return(status: 500)

    expect(delete.failure).to eq([:unavailable])
    expect(rows(:shares)).to eq(1)
  end

  it "answers not found for a missing share" do
    expect(delete(0).failure).to eq(:not_found)
  end
end
