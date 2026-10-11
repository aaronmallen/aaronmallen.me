# frozen_string_literal: true

RSpec.describe Shares::Operations::SetShareAltText do
  let(:share) { upload_share.value! }

  def set(alt_text, id: share.id) = described_class.new.call(id, alt_text:)

  before do
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
  end

  it "sets the alt text, trimmed" do
    expect(set("  A cat on a desk ").value!.alt_text).to eq("A cat on a desk")
  end

  it "clears the alt text when blank" do
    set("A cat")

    expect(set(" ").value!.alt_text).to be_nil
  end

  it "refuses control characters" do
    expect(set("A\u0000cat").failure).to eq([:invalid, { alt_text: ["control"] }])
  end

  it "answers not found for a missing share" do
    expect(set("A cat", id: 0).failure).to eq(:not_found)
  end
end
