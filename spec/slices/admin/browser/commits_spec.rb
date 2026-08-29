# frozen_string_literal: true

RSpec.describe "Admin commits card", type: :feature do
  let(:queued) { "Import queued · new commits show on the card shortly" }

  def animations
    page.evaluate_script(
      "document.getAnimations().filter((a) => a.constructor.name === 'CSSAnimation').map((a) => a.animationName)",
    )
  end

  def hold_the_page
    page.execute_script(
      "document.querySelector('[data-commits-import]').addEventListener('submit', (e) => e.preventDefault())",
    )
  end

  def stub_token
    connect_github(client_id: "client-id", client_secret: "client-secret", api_token: "ghp_token")
  end

  def visit_today
    sign_in_to_admin
    visit "/admin"
  end

  describe "with a token" do
    before do
      stub_token
      visit_today
    end

    it "animates nothing before the import starts" do
      expect(animations).to be_empty
    end

    it "reads Importing… on a disabled button while the form submits", :aggregate_failures do
      hold_the_page
      click_button "Import now"

      expect(page).to have_button("Importing…", disabled: true)
      expect(page).to have_no_button("Import now")
    end

    it "spins the icon while the form submits, and nothing else on the page moves" do
      hold_the_page
      click_button "Import now"

      expect(animations).to eq(["spin"])
    end

    describe "when the import is queued" do
      before do
        click_button "Import now"
        page.assert_selector(".toast", text: queued)
      end

      it "leaves the card alone, since the worker imports the commits" do
        expect(page).to have_no_css(".commit-message")
      end

      it "goes back to Import now" do
        expect(page).to have_button("Import now", disabled: false)
      end

      it "stops the spinner" do
        expect(animations).to be_empty
      end
    end
  end

  describe "without a token" do
    before do
      disconnect_github
      visit_today
    end

    it "disables Import now with a hint", :aggregate_failures do
      expect(page).to have_button("Import now", disabled: true)
      expect(page).to have_css(".card .hint", text: "No GitHub token is set")
    end

    it "animates nothing" do
      expect(animations).to be_empty
    end
  end
end
