# frozen_string_literal: true

RSpec.describe "Content security policy", type: :app do
  def font_sources
    stylesheet = Hanami.app.root.join("public", Hanami.app["assets"]["app.css"].url.delete_prefix("/")).read
    stylesheet.scan(/@font-face\s*{[^}]*}/).flat_map { it.scan(/url\(\s*["']?([^"')]+)/).flatten }
  end

  it "draws every face in the stylesheet from the site", :aggregate_failures do
    expect(font_sources).not_to be_empty
    expect(font_sources).to all(start_with("./"))
  end
end
