# frozen_string_literal: true

RSpec.describe Shares::Helpers::Code do
  it "never picks a taken code" do
    taken = described_class::ALPHABET.repeated_permutation(2).map(&:join) - %w[a2 z9]

    expect(Array.new(50) { described_class.pick(2, taken) }.uniq).to contain_exactly("a2", "z9")
  end

  it "picks nothing once every code of the length is taken" do
    expect(described_class.pick(1, described_class::ALPHABET)).to be_nil
  end

  it "skips typed codes of other lengths or letters", :aggregate_failures do
    taken = described_class::ALPHABET - ["q"] + %w[0 talk]

    expect(described_class.pick(1, taken)).to eq("q")
    expect(described_class.pick(1, %w[1 i l o])).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]\z/)
  end
end
