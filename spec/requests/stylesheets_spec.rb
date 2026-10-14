# frozen_string_literal: true

RSpec.describe "Stylesheets", type: :request do
  def asset(source) = Hanami.app["assets"][source].url

  def stylesheets = Capybara.string(last_response.body).all("link[rel='stylesheet']", visible: :all).map { it[:href] }

  it "links the public sheet alone on a public page" do
    get "/privacy"

    expect(stylesheets).to eq([asset("public/app.css")])
  end

  it "links the admin sheet alone on an admin page" do
    sign_in_to_admin
    get "/admin"

    expect(stylesheets).to eq([asset("admin/app.css")])
  end

  it "leaves the admin's styles out of the public sheet" do
    public_sheet = Hanami.app.root.join("public", asset("public/app.css").delete_prefix("/")).read

    expect(public_sheet).not_to include(".adm-main")
  end
end
