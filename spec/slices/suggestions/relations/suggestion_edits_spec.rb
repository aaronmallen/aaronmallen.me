# frozen_string_literal: true

RSpec.describe Suggestions::Relations::SuggestionEdits do
  it "keeps the status's Ruby twin in the enum's order" do
    db = Suggestions::Slice["db.rom"].gateways[:default].connection

    expect(db.fetch("SELECT unnest(enum_range(NULL::suggestion_edit_status))::text AS status").map { it[:status] })
      .to eq(Blog::Types::SuggestionEditStatus.values)
  end
end
