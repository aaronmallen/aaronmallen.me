# frozen_string_literal: true

RSpec.describe SavedViews::Queries::ScreenFilters do
  subject(:screen_filters) { SavedViews::Slice["queries.screen_filters"] }

  Blog::Types::SavedViewScreen.each_value do |screen|
    it "lists the filters a #{screen} view keeps" do
      names = screen_filters.call(screen)
      view = create(:saved_view, screen:, filters: names.to_h { [it, "x"] }.merge("page" => "2"))

      expect(SavedViews::Slice["queries.by_id"].call(view.id).filters.keys).to match_array(names)
    end
  end
end
