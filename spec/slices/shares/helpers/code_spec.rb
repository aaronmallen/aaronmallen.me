# frozen_string_literal: true

RSpec.describe Shares::Helpers::Code do
  it "draws a full code from the alphabet" do
    expect(described_class.pad).to match(/\A[abcdefghjkmnpqrstuvwxyz23456789]{8}\z/)
  end

  it "pads a short code to 8 and keeps its start" do
    expect(described_class.pad("talk")).to match(/\Atalk[abcdefghjkmnpqrstuvwxyz23456789]{4}\z/)
  end

  it "leaves a code of 8 or more alone" do
    expect(described_class.pad("abcdefghjkmnpqrs")).to eq("abcdefghjkmnpqrs")
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
