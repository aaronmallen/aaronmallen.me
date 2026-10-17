# frozen_string_literal: true

RSpec.describe Blog::Operation do
  subject(:operation) do
    Class.new(described_class) do
      def guard(repo, map, &) = constrained(repo, map, &)
    end.new
  end

  def broken(kind, constraint)
    repo = instance_double(Blog::DB::Repo, violated_constraint: constraint)
    [repo, -> { raise kind, StandardError.new(constraint) }]
  end

  it "passes the block's result through" do
    expect(operation.guard(nil, {}) { Success(1) }).to eq(Success(1))
  end

  it "turns each known constraint into a one-field failure", :aggregate_failures do
    described_class::CONSTRAINT_ERRORS.each do |kind|
      repo, save = broken(kind, "things_name_key")

      expect(operation.guard(repo, { "things_name_key" => [:name, "taken"] }, &save))
        .to eq(Failure([:invalid, { name: ["taken"] }]))
    end
  end

  it "turns a constraint mapped to a code into that failure" do
    repo, save = broken(ROM::SQL::UniqueConstraintError, "things_name_key")

    expect(operation.guard(repo, { "things_name_key" => :taken }, &save)).to eq(Failure(:taken))
  end

  it "raises an unknown constraint" do
    repo, save = broken(ROM::SQL::CheckConstraintError, "things_other_check")

    expect { operation.guard(repo, { "things_name_key" => [:name, "taken"] }, &save) }
      .to raise_error(ROM::SQL::CheckConstraintError)
  end
end
