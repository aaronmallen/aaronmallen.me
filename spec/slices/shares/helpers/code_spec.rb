# frozen_string_literal: true

RSpec.describe Shares::Helpers::Code do
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
