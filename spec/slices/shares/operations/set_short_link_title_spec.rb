# frozen_string_literal: true

RSpec.describe Shares::Operations::SetShortLinkTitle do
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination: "https://example.com").value! }

  def set(title, id: link.id) = described_class.new.call(id, title:)

  it "sets and clears the title", :aggregate_failures do
    expect(set(" My talk ").value!.title).to eq("My talk")
    expect(set(" ").value!.title).to be_nil
  end

  it "refuses control characters" do
    expect(set("bad\u0007").failure).to eq([:invalid, { title: ["control"] }])
  end

  it "answers not found for a missing link" do
    expect(set("x", id: 0).failure).to eq(:not_found)
  end
end
