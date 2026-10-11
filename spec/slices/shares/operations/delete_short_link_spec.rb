# frozen_string_literal: true

RSpec.describe Shares::Operations::DeleteShortLink do
  let(:link) { Shares::Slice["operations.create_short_link"].call(destination: "https://example.com").value! }

  def rows(name) = Shares::Slice["relations.#{name}"].count

  it "removes the link and its code", :aggregate_failures do
    expect(described_class.new.call(link.id)).to be_success
    expect(rows(:short_links)).to eq(0)
    expect(rows(:short_codes)).to eq(0)
  end

  it "answers not found for a missing link" do
    expect(described_class.new.call(0).failure).to eq(:not_found)
  end
end
