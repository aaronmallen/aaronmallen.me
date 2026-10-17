# frozen_string_literal: true

RSpec.describe SavedViews::Relations::SavedViews do
  it "refuses a blank name" do
    expect { create(:saved_view, name: " ") }.to raise_error(ROM::SQL::CheckConstraintError, /non_blank_text_check/)
  end

  it "refuses a long name" do
    expect { create(:saved_view, name: "a" * 101) }
      .to raise_error(ROM::SQL::CheckConstraintError, /saved_views_name_length_check/)
  end

  it "refuses filters that are not an object" do
    expect { create(:saved_view, filters: ["q"]) }
      .to raise_error(ROM::SQL::CheckConstraintError, /saved_views_filters_check/)
  end

  it "keeps the screen's Ruby twin in the enum's order" do
    expect(enum_labels(SavedViews::Slice, :saved_view_screen)).to eq(Blog::Types::SavedViewScreen.values)
  end
end
