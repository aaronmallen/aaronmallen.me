# frozen_string_literal: true

RSpec.describe "Admin journal, decision, file, link and tag row menus", type: :feature do
  def open_menu(target)
    box = target.evaluate_script("JSON.parse(JSON.stringify(this.getBoundingClientRect()))")
    keep_page
    page.driver.browser.mouse.click(x: box["left"] + 2, y: box["top"] + (box["height"] / 2), button: :right)
    menu
  end

  before { sign_in_to_admin }

  describe "a journal entry" do
    let(:entry) { create(:journal_entry, body: "shipped it") }

    before do
      create(:tag, :private, name: "home")
      entry
      visit "/admin/journal"
      watch_clipboard
      open_menu(find(".journal-entry time"))
    end

    def tick
      item("Tags").hover
      item("#home").click
    end

    it "tags it in place on a tick", :aggregate_failures do
      tick

      expect(page).to have_css(".toast", text: "Tagged home")
      expect(page).to have_css(".journal-entry .tag", text: "#home")
      expect(kept_page?).to be(true)
    end

    it "untags it on an untick" do
      tick
      find(".journal-entry .tag", text: "#home")
      open_menu(find(".journal-entry time"))
      tick

      expect(page).to have_css(".toast", text: "Took home off")
    end

    it "copies the text with a toast", :aggregate_failures do
      item("Copy text").click

      expect(page).to have_css(".toast", text: admin_t("ui.views.journal.menu.copied_text"))
      expect(evaluate_script("window.copiedKeys")).to eq(["shipped it"])
    end

    describe "deleting" do
      before { item("Delete entry").click }

      it "asks for a second click" do
        expect(item(admin_t("ui.components.context_menu.confirm.forever"))).to be_truthy
      end

      it "deletes in place on the second click", :aggregate_failures do
        item(admin_t("ui.components.context_menu.confirm.forever")).click

        expect(page).to have_css(".toast", text: admin_t("journal_page.toasts.deleted"))
        expect(page).to have_no_css(".journal-entry")
        expect(kept_page?).to be(true)
      end
    end
  end

  describe "an open decision" do
    let(:decision) { create(:decision, title: "Pick a queue") }
    let(:dialog) { find("dialog#decision-#{decision.id}-drop") }

    def drop = dialog.click_button(admin_t("ui.components.decisions.reason_form.submit.drop"))

    before do
      decision
      visit "/admin/decisions"
      open_menu(find(".decision-meta"))
      item("Drop…").click
    end

    it "opens the reason form in a dialog" do
      expect(dialog).to have_field("decision[reason]")
    end

    it "shows the error it shows today when the reason is blank", :aggregate_failures do
      drop

      expect(dialog).to have_css(".field-error", text: admin_t("ui.components.decisions.field_error.reason.blank"))
      expect(Decisions::Slice["repos.decision_queries"].by_id(decision.id).status).to eq("open")
    end

    it "drops it in place with the reason", :aggregate_failures do
      dialog.fill_in("decision[reason]", with: "moot")
      drop

      expect(page).to have_css(".toast", text: admin_t("decisions_page.toasts.dropped"))
      expect(page).to have_no_css(".decision-row", text: "Pick a queue")
      expect(kept_page?).to be(true)
    end

    it "drops it after a blank try" do
      drop
      dialog.find(".field-error")
      dialog.fill_in("decision[reason]", with: "moot")
      drop

      expect(page).to have_css(".toast", text: admin_t("decisions_page.toasts.dropped"))
    end
  end

  describe "a file" do
    before do
      connect_share_store
      stub_request(:put, %r{\A#{share_store_url}/})
      upload_share("x", "deck.pdf", "application/pdf")
      visit "/admin/files"
      watch_clipboard
      open_menu(find(".file-card-meta"))
    end

    it "opens its details" do
      item("Details").click

      expect(page).to have_css("dialog.file-drawer[open]")
    end

    it "copies its link with a toast", :aggregate_failures do
      item("Copy link").click

      expect(page).to have_css(".toast", text: admin_t("ui.views.files.menu.copied_link"))
      expect(evaluate_script("window.copiedKeys").first).to start_with("http://shares.localhost/")
    end
  end

  describe "a link" do
    before do
      Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com/talk", code: "talk" })
      visit "/admin/links"
      open_menu(find(".link-row-meta"))
    end

    it "deletes in place on the second click", :aggregate_failures do
      item("Delete link").click
      item(admin_t("ui.views.links.menu.confirm_delete")).click

      expect(page).to have_css(".toast", text: admin_t("links_page.toasts.deleted"))
      expect(page).to have_no_css(".link-row")
      expect(kept_page?).to be(true)
    end
  end

  describe "a row whose title link covers it" do
    before do
      Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com/talk", code: "talk" })
      visit "/admin/links"
    end

    it "keeps the browser's menu on the link's own text" do
      find(".link-row-title a").right_click

      expect(page).to have_no_css("[data-context-menu]", wait: 0.5)
    end
  end

  describe "a tag" do
    before do
      create(:tag, :private, name: "home", color: "mk-blue")
      visit "/admin/tags?scope=private"
      open_menu(find(".tag-uses"))
      item("Colour").hover
      item("Pink").click
    end

    it "recolours it in place", :aggregate_failures do
      expect(page).to have_css(".toast", text: admin_t("tags_page.toasts.recoloured"))
      expect(Tags::Slice["repos.tag_queries"].all_in("private").map(&:color)).to eq(["mk-pink"])
      expect(kept_page?).to be(true)
    end
  end
end
