# frozen_string_literal: true

RSpec.describe Shares::Operations::RetargetShortLink do
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination: "https://example.com").value! }

  def retarget(destination, id: link.id) = described_class.new.call(id, destination:)

  it "points the link somewhere new and stamps when", :aggregate_failures do
    moved = retarget(" https://example.org/new ").value!

    expect(moved.destination).to eq("https://example.org/new")
    expect(moved.code).to eq(link.code)
    expect(moved.retargeted_at).not_to be_nil
  end

  it "leaves the stamp alone when the destination stays the same" do
    expect(retarget(link.destination).value!.retargeted_at).to be_nil
  end

  it "refuses a link that is not http or https" do
    expect(retarget("javascript:alert(1)").failure).to eq([:invalid, { destination: ["format"] }])
  end

  it "answers not found for a missing link" do
    expect(retarget("https://example.org", id: 0).failure).to eq(:not_found)
  end
end
