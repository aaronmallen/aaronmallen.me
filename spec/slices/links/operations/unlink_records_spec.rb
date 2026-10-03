# frozen_string_literal: true

RSpec.describe Links::Operations::UnlinkRecords do
  include Dry::Monads[:result]

  let(:task) { linkable_record("task") }
  let(:entry) { linkable_record("journal_entry") }

  def stored = Links::Slice["relations.record_links"].count

  def unlink(...) = Links::Slice["operations.unlink_records"].call(...)

  before do
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "journal_entry", other_id: entry.id })
  end

  it "removes a link from the side that made it", :aggregate_failures do
    expect(unlink("task", task.id, "journal_entry", entry.id)).to eq(Success(1))
    expect(stored).to eq(0)
  end

  it "removes a link from the other side", :aggregate_failures do
    expect(unlink("journal_entry", entry.id.to_s, "task", task.id.to_s)).to eq(Success(1))
    expect(stored).to eq(0)
  end

  it "answers not found when the records are not linked" do
    expect(unlink("task", task.id, "journal_entry", linkable_record("journal_entry").id)).to eq(Failure(:not_found))
  end

  it "answers not found for a kind it does not know" do
    expect(unlink("task", task.id, "person", entry.id)).to eq(Failure(:not_found))
  end

  it "answers not found for an id that is not a number" do
    expect(unlink("task", "abc", "journal_entry", entry.id)).to eq(Failure(:not_found))
  end
end
