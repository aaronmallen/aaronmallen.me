# frozen_string_literal: true

RSpec.describe Suggestions::Relations::SuggestionEdits do
  it "keeps the status's Ruby twin in the enum's order" do
    expect(enum_labels(Suggestions::Slice, :suggestion_edit_status)).to eq(Blog::Types::SuggestionEditStatus.values)
  end
end
