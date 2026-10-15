# frozen_string_literal: true

RSpec.describe Shares::Operations::ChangeShortLinkCode do
  it "answers not found for a missing link" do
    expect(described_class.new.call(0, code: "talk").failure).to eq(:not_found)
  end
end
