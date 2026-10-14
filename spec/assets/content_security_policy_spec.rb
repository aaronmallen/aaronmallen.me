# frozen_string_literal: true

RSpec.describe "Content security policy", type: :app do
  def font_sources(sheet)
    stylesheet = Hanami.app.root.join("public", Hanami.app["assets"][sheet].url.delete_prefix("/")).read
    stylesheet.scan(/@font-face\s*{[^}]*}/).flat_map { it.scan(/url\(\s*["']?([^"')]+)/).flatten }
  end

  %w[public/app.css admin/app.css].each do |sheet|
    it "draws every face in #{sheet} from the site", :aggregate_failures do
      expect(font_sources(sheet)).not_to be_empty
      expect(font_sources(sheet)).to all(start_with("../"))
    end
  end
end
