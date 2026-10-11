# frozen_string_literal: true

RSpec.describe Shares::Operations::ChangeShortLinkCode do
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination: "https://example.com").value! }

  def change(code, id: link.id) = described_class.new.call(id, code:)

  def codes = Shares::Slice["relations.short_codes"].pluck(:code)

  it "changes the code and frees the old one", :aggregate_failures do
    expect(change(" Talk ").value!.code).to eq("talk")
    expect(codes).to eq(["talk"])
  end

  it "refuses a code another link holds" do
    other = Shares::Slice["operations.create_short_link"].call(destination: "https://example.org").value!

    expect(change(other.code).failure).to eq([:invalid, { code: ["taken"] }])
  end

  it "refuses a code that breaks the format" do
    expect(change("ta lk").failure).to eq([:invalid, { code: ["format"] }])
  end

  it "answers not found for a missing link" do
    expect(change("talk", id: 0).failure).to eq(:not_found)
  end
end
