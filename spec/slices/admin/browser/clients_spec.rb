# frozen_string_literal: true

RSpec.describe "Admin MCP clients", type: :feature do
  include Spec::DB::FactoryHelper.new(:mcp)

  let(:row) { find(".li", text: "Claude") }

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before do
    create(:oauth_token, oauth_client: create(:oauth_client, client_name: "Claude"))
    sign_in_to_admin
    visit "/admin/clients"
  end

  it "asks with the confirmation text" do
    message = dismiss_confirm { row.click_button "Revoke" }

    expect(message).to eq(translate("ui.components.client_row.confirm_revoke", client: "Claude"))
  end

  it "keeps the client listed when I don't confirm", :aggregate_failures do
    dismiss_confirm { row.click_button "Revoke" }

    expect(page).to have_no_css(".toast")
    expect(page).to have_css(".li-title", text: "Claude")
  end

  it "revokes once I confirm" do
    accept_confirm { row.click_button "Revoke" }

    expect(page).to have_css(".toast", text: "Access revoked")
  end
end
