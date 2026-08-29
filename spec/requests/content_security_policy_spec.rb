# frozen_string_literal: true

RSpec.describe "Content security policy", type: :request do
  def directive(name) = policy.find { it.start_with?("#{name} ") }

  def font_sources
    stylesheet = Hanami.app.root.join("public", Hanami.app["assets"]["app.css"].url.delete_prefix("/")).read
    stylesheet.scan(/@font-face\s*{[^}]*}/).flat_map { it.scan(/url\(\s*["']?([^"')]+)/).flatten }
  end

  def policy = last_response.headers["Content-Security-Policy"].split(";").map(&:strip)

  it "draws every face in the stylesheet from the site", :aggregate_failures do
    expect(font_sources).not_to be_empty
    expect(font_sources).to all(start_with("./"))
  end

  describe "a public page" do
    before { get "/" }

    it "loads fonts from the site alone" do
      expect(directive("font-src")).to eq("font-src 'self'")
    end
  end

  describe "an admin page" do
    before do
      sign_in_to_admin
      get "/admin/tags"
    end

    it "loads fonts from the site alone" do
      expect(directive("font-src")).to eq("font-src 'self'")
    end
  end
end
