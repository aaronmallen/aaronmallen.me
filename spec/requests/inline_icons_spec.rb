# frozen_string_literal: true

RSpec.describe "Inline icons", type: :request do
  def icons = Capybara.string(last_response.body).all("i", visible: :all)

  it "draws every public icon as inline SVG", :aggregate_failures do
    get "/contact"

    expect(icons).not_to be_empty
    expect(icons).to all(have_css("svg", visible: :all))
  end

  it "keeps admin icons on the icon font" do
    sign_in_to_admin
    get "/admin"

    expect(icons.select { it.has_css?("svg", visible: :all) }).to be_empty
  end
end
