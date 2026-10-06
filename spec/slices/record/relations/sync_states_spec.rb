# frozen_string_literal: true

RSpec.describe Record::Relations::SyncStates do
  def labels(type)
    db = Record::Slice["db.rom"].gateways[:default].connection

    db.fetch("SELECT unnest(enum_range(NULL::#{type}))::text AS label").map { it[:label] }
  end

  it "keeps the sync name's Ruby twin in the enum's order" do
    expect(labels("sync_name")).to eq(Blog::Types::SyncName.values)
  end

  it "keeps the sync state kind's Ruby twin in the enum's order" do
    expect(labels("sync_state_kind")).to eq(Blog::Types::SyncStateKind.values)
  end
end
