# frozen_string_literal: true

RSpec.describe Record::Relations::SyncStates do
  it "keeps the sync name's Ruby twin in the enum's order" do
    expect(enum_labels(Record::Slice, :sync_name)).to eq(Blog::Types::SyncName.values)
  end

  it "keeps the sync state kind's Ruby twin in the enum's order" do
    expect(enum_labels(Record::Slice, :sync_state_kind)).to eq(Blog::Types::SyncStateKind.values)
  end
end
