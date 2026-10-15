# frozen_string_literal: true

RSpec.describe "Stylesheets", type: :request do
  def asset(source) = Hanami.app["assets"][source].url

  def sheet(source) = Hanami.app.root.join("public", asset(source).delete_prefix("/")).read

  it "links the public sheet alone on a public page" do
    get "/privacy"

    expect(stylesheets).to eq([asset("public/app.css")])
  end

  it "links the admin sheet alone on an admin page" do
    sign_in_to_admin
    get "/admin"

    expect(stylesheets).to eq([asset("admin/app.css")])
  end

  def stylesheets = Capybara.string(last_response.body).all("link[rel='stylesheet']", visible: :all).map { it[:href] }

  it "leaves the admin's styles out of the public sheet" do
    expect(sheet("public/app.css")).not_to include(".adm-main")
  end

  it "leaves Font Awesome's styles and fonts out of the public sheet", :aggregate_failures do
    expect(sheet("public/app.css")).not_to include("Font Awesome")
    expect(sheet("public/app.css")).not_to match(/fa-(brands|regular|solid)-\d+/)
  end

  it "keeps Font Awesome in the admin sheet" do
    expect(sheet("admin/app.css")).to include("fa-solid-900")
  end
end
