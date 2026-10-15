# frozen_string_literal: true

RSpec.describe Shares::Operations::RetargetShortLink do
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination: "https://example.com").value! }

  def retarget(destination, id: link.id) = described_class.new.call(id, destination:)

  it "leaves the stamp alone when the destination stays the same" do
    expect(retarget(link.destination).value!.retargeted_at).to be_nil
  end

  it "answers not found for a missing link" do
    expect(retarget("https://example.org", id: 0).failure).to eq(:not_found)
  end
end
