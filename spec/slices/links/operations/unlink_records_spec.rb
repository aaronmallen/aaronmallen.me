# frozen_string_literal: true

RSpec.describe Links::Operations::UnlinkRecords do
  include Dry::Monads[:result]

  let(:task) { linkable_record("task") }
  let(:entry) { linkable_record("journal_entry") }

  def unlink(...) = Links::Slice["operations.unlink_records"].call(...)

  before do
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "journal_entry", other_id: entry.id })
  end

  it "answers not found for a kind it does not know" do
    expect(unlink("task", task.id, "person", entry.id)).to eq(Failure(:not_found))
  end

  it "answers not found for an id that is not a number" do
    expect(unlink("task", "abc", "journal_entry", entry.id)).to eq(Failure(:not_found))
  end
end
