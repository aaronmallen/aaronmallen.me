# frozen_string_literal: true

RSpec.describe "MCP authorization", type: :feature do
  include Spec::DB::FactoryHelper.new(:mcp)

  let(:client) { create(:oauth_client, client_name: "Claude", redirect_uris: [redirect_uri]) }
  let(:redirect_uri) { "http://localhost:#{page.server.port}/callback" }

  def authorize_path
    params = {
      client_id: client.client_id,
      code_challenge: MCP::Slice["operations.derive_code_challenge"].call(Blog::Types::NewSecret[]),
      code_challenge_method: "S256",
      redirect_uri:,
      resource: "https://aaronmallen.me/mcp",
      response_type: "code",
      scope: "read",
      state: "state-from-claude",
    }

    "/oauth/authorize?#{Rack::Utils.build_query(params)}"
  end

  def landed_with(param)
    have_current_path(/\A#{Regexp.escape(redirect_uri)}\?.*\b#{param}/, url: true)
  end

  def press_by_keyboard(label)
    focused = Enumerator.produce { tab }.lazy.take(10).find { it["text"] == label }
    page.driver.browser.keyboard.type(:enter)
    focused
  end

  def tab
    page.driver.browser.keyboard.type(:tab)
    evaluate_script(<<~JS)
      (() => {
        const el = document.activeElement;
        const style = getComputedStyle(el);
        const outline = style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0;
        return { text: el.textContent.trim(), ring: outline || style.boxShadow !== 'none' };
      })()
    JS
  end

  before do
    sign_in_to_admin
    visit authorize_path
  end

  it "lands on the redirect URI once I approve" do
    click_button "Approve"

    expect(page).to landed_with("code=")
  end

  it "approves by keyboard alone, behind a focus ring", :aggregate_failures do
    expect(press_by_keyboard("Approve")).to include("ring" => true)
    expect(page).to landed_with("code=")
  end

  it "refuses by keyboard alone, behind a focus ring", :aggregate_failures do
    expect(press_by_keyboard("Cancel")).to include("ring" => true)
    expect(page).to landed_with("error=access_denied")
  end
end
