# frozen_string_literal: true

RSpec.describe "Admin API tokens", type: :feature do
  let(:row) { find(".li", text: "Laptop") }

  def mint(name)
    fill_in "Token name", with: name
    click_button "Mint token"
    find(".toast", text: "Token minted")
  end

  before do
    API::Slice["operations.mint_token"].call(name: "Laptop")
    sign_in_to_admin
    visit "/admin/tokens"
  end

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  it "shows a new token" do
    mint("Terminal")

    expect(page).to have_field("New API token", with: /\A[A-Za-z0-9_-]{43}\z/)
  end

  it "hides the new token once I reload", :aggregate_failures do
    mint("Terminal")
    visit "/admin/tokens"

    expect(page).to have_css(".li-title", text: "Terminal")
    expect(page).to have_no_field("New API token")
  end

  it "asks with the confirmation text" do
    message = dismiss_confirm { row.click_button "Revoke" }

    expect(message).to eq(translate("ui.components.tokens.row.confirm_revoke", token: "Laptop"))
  end

  it "keeps the token listed when I don't confirm", :aggregate_failures do
    dismiss_confirm { row.click_button "Revoke" }

    expect(page).to have_no_css(".toast")
    expect(page).to have_css(".li-title", text: "Laptop")
  end

  it "revokes once I confirm", :aggregate_failures do
    accept_confirm { row.click_button "Revoke" }

    expect(page).to have_css(".toast", text: "Token revoked")
    expect(page).to have_no_css(".li-title", text: "Laptop")
  end
end
