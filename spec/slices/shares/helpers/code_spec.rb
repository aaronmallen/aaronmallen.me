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

  def collide(constraint, fails: Float::INFINITY)
    repo = instance_double(Blog::DB::Repo, violated_constraint: constraint)
    error = ROM::SQL::UniqueConstraintError.new(StandardError.new(constraint))
    tries = 0
    [repo, -> { (tries += 1) > fails ? tries : raise(error) }, -> { tries }]
  end

  it "retries a code collision until a try lands" do
    repo, insert = collide(described_class::KEY, fails: 2)

    expect(described_class.retrying(repo, &insert)).to eq(3)
  end

  it "raises a code collision once the tries run out", :aggregate_failures do
    repo, insert, tries = collide(described_class::KEY)

    expect { described_class.retrying(repo, &insert) }.to raise_error(ROM::SQL::UniqueConstraintError)
    expect(tries.call).to eq(described_class::ATTEMPTS)
  end

  it "raises a collision on any other constraint", :aggregate_failures do
    repo, insert, tries = collide("shares_key_key")

    expect { described_class.retrying(repo, &insert) }.to raise_error(ROM::SQL::UniqueConstraintError)
    expect(tries.call).to eq(1)
  end
end
