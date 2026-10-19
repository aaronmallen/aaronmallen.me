# frozen_string_literal: true

RSpec.describe "Admin journal, decision, file, link and tag row menus", type: :request do
  let(:page) { Capybara.string(last_response.body) }

  def blank = admin_t("ui.components.decisions.field_error.reason.blank")

  def copies = page.all("[data-copy]", visible: :all).to_h { [it.find(".ctx-label").text(:all), it["data-copy"]] }

  def form(route) = page.first("form[action='#{route}']", visible: :all)

  def return_to(form) = form.find("input[name=return_to]", visible: :all).value

  def returns = page.all("[data-context-menu] form", visible: :all).map { return_to(it) }.uniq

  def short_link(destination, **) = Shares::Slice["operations.create_short_link"].call({ destination:, ** }).value!

  describe "signed in" do
    before { sign_in_to_admin }

    %w[journal decisions files links tags].each do |kind|
      it "answers 404 for a #{kind} row that is gone" do
        get "/admin/#{kind}/0/menu"

        expect(last_response.status).to eq(404)
      end
    end

    describe "a journal entry" do
      let(:entry) do
        create(:journal_entry, body: "shipped it", entry_date: Date.new(2026, 10, 1), entry_time: "09:30")
      end

      before do
        create(:tag, :private, name: "home")
        create(:tag, :private, name: "work")
        create(:tag, name: "ruby")
        Record::Slice["repos.journal_entry_mutations"].replace_tags(entry.id, ["home"])
        get "/admin/journal/#{entry.id}/menu", return_to: "/admin/journal?q=ship"
      end

      it "heads the menu with the entry's date and time" do
        expect(page).to have_css("[data-context-menu] > .ctx-head", text: "Oct 1 · 09:30")
      end

      it "holds every action an entry takes" do
        expect(menu_items).to eq(["Edit", "Linked records", "Tags", "#home", "#work", "Copy text", "Delete entry"])
      end

      it "edits and shows links on the entry's day", :aggregate_failures do
        edit = "/admin/journal?to=2026-10-01&edit=#{entry.id}"

        expect(page).to have_css("a.ctx-item[href='#{edit}']", text: "Edit")
        expect(page).to have_css("a.ctx-item[href='#{edit}#journal-links-#{entry.id}']", text: "Linked records")
      end

      it "posts every action back to the page it opened on" do
        expect(returns).to eq(["/admin/journal?q=ship"])
      end

      it "unticks a tag it has and ticks one it lacks", :aggregate_failures do
        expect(page).to have_css("[role=menuitemcheckbox][aria-checked=true]", text: "#home", visible: :all)
        expect(form("/admin/journal/#{entry.id}/tags/delete")).to have_field("tag", type: :hidden, with: "home")
        expect(form("/admin/journal/#{entry.id}/tags")).to have_field("tag", type: :hidden, with: "work")
      end

      it "lists only private tags" do
        expect(page).to have_no_css("[role=menuitemcheckbox]", text: "#ruby", visible: :all)
      end

      it "copies the text" do
        expect(copies["Copy text"]).to eq("shipped it")
      end

      it "asks before it deletes" do
        confirm = admin_t("ui.components.context_menu.confirm.forever")

        expect(form("/admin/journal/#{entry.id}/delete").find("button")["data-confirm-inline"]).to eq(confirm)
      end

      it "lands a delete back on the page it opened on", :aggregate_failures do
        admin_post("/admin/journal/#{entry.id}/delete", return_to: "/admin/journal?q=ship")

        expect(last_response.location).to eq("/admin/journal?q=ship")
        follow_redirect!
        expect(toast).to eq(admin_t("journal_page.toasts.deleted"))
      end
    end

    describe "an open decision" do
      let(:decision) { create(:decision, title: "Pick a queue") }

      before do
        create(:tag, :private, name: "infra")
        get "/admin/decisions/#{decision.id}/menu", return_to: "/admin/decisions?status=open"
      end

      it "heads the menu with the decision's number and title" do
        expect(page).to have_css(".ctx-head", text: "##{decision.id} · Pick a queue")
      end

      it "holds every action an open decision takes", :aggregate_failures do
        expect(menu_items).to eq(["Open", "Edit", "Copy number", "Tags", "#infra", "Drop…"])
        expect(copies["Copy number"]).to eq("##{decision.id}")
      end

      it "opens the drop reason form in a dialog that posts back to the page", :aggregate_failures do
        dialog = page.find("dialog#decision-#{decision.id}-drop", visible: :all)
        drop = dialog.find("form#decision-drop-form[data-morph]", visible: :all)

        expect(page).to have_css("a[data-dialog-open='decision-#{decision.id}-drop']", text: "Drop…")
        expect(drop[:action]).to eq("/admin/decisions/#{decision.id}/drop")
        expect(return_to(drop)).to eq("/admin/decisions?status=open")
      end

      it "tells screen readers that Drop opens a dialog" do
        expect(page.find("a", text: "Drop…", visible: :all)["aria-haspopup"]).to eq("dialog")
      end

      it "tags through the decision's tag route" do
        expect(form("/admin/decisions/#{decision.id}/tags")).to have_css("input[name=tag][value=infra]", visible: :all)
      end
    end

    describe "a dropped decision" do
      let(:decision) { create(:decision, status: "dropped") }

      before { get "/admin/decisions/#{decision.id}/menu" }

      it "offers reopen in place of drop", :aggregate_failures do
        expect(menu_items).to include("Reopen…")
        expect(menu_items).not_to include("Drop…")
      end

      it "opens the reopen reason form" do
        expect(form("/admin/decisions/#{decision.id}/reopen")[:id]).to eq("decision-reopen-form")
      end
    end

    describe "dropping from the menu" do
      let(:decision) { create(:decision) }

      it "lands back on the page it opened on", :aggregate_failures do
        admin_post("/admin/decisions/#{decision.id}/drop", decision: { reason: "moot" }, return_to: "/admin/decisions")

        expect(last_response.location).to eq("/admin/decisions")
        follow_redirect!
        expect(toast).to eq(admin_t("decisions_page.toasts.dropped"))
      end

      it "refuses a blank reason with the form and its error", :aggregate_failures do
        admin_post("/admin/decisions/#{decision.id}/drop", decision: { reason: "" }, return_to: "/admin/decisions")

        expect(last_response.status).to eq(422)
        expect(form("/admin/decisions/#{decision.id}/drop")[:id]).to eq("decision-drop-form")
        expect(form("/admin/decisions/#{decision.id}/drop")).to have_text(blank)
      end
    end

    describe "a file" do
      def share(name, type) = upload_share("x", name, type).value!

      before do
        connect_share_store
        stub_request(:put, %r{\A#{share_store_url}/})
      end

      describe "that is not an image" do
        let(:file) { share("deck.pdf", "application/pdf") }
        let(:link) { "http://shares.localhost/#{file.code}" }

        before { get "/admin/files/#{file.id}/menu", return_to: "/admin/files?kind=other" }

        it "holds every action a file takes", :aggregate_failures do
          expect(menu_items).to eq(["Details", "Open file", "Copy link", "Copy as markdown", "Delete file"])
          expect(returns).to eq(["/admin/files?kind=other"])
        end

        it "opens its details and the file", :aggregate_failures do
          expect(page).to have_css("a[data-dialog-open='share-#{file.id}-drawer']", text: "Details")
          expect(page).to have_css("a.ctx-item[href='#{link}'][target=_blank]", text: "Open file")
        end

        it "copies its link and markdown" do
          expect(copies).to include("Copy link" => link, "Copy as markdown" => "[deck.pdf](#{link})")
        end
      end

      it "copies an image as an image" do
        file = share("shot.png", "image/png")
        get "/admin/files/#{file.id}/menu"

        expect(copies["Copy as markdown"]).to eq("![](http://shares.localhost/#{file.code})")
      end

      it "lands a delete back on the page it opened on" do
        file = share("deck.pdf", "application/pdf")
        stub_request(:delete, share_store_url(file.key))
        admin_post("/admin/files/#{file.id}/delete", return_to: "/admin/files?kind=other")

        expect(last_response.location).to eq("/admin/files?kind=other")
      end
    end

    describe "a link" do
      let(:link) { short_link("https://example.com/talk", code: "talk-now") }

      before { get "/admin/links/#{link.id}/menu", return_to: "/admin/links?sort=clicks" }

      it "holds every action a link takes", :aggregate_failures do
        expect(menu_items).to eq(
          ["Edit", "Open destination", "Copy short link", "Copy destination", "Copy as markdown", "Delete link"],
        )
        expect(page).to have_css("a[data-dialog-open='link-#{link.id}-drawer']", text: "Edit")
      end

      it "copies the short link, the destination and markdown" do
        expect(copies).to eq(
          "Copy short link" => "http://shares.localhost/talk-now",
          "Copy destination" => "https://example.com/talk",
          "Copy as markdown" => "[example.com](http://shares.localhost/talk-now)",
        )
      end

      it "lands a delete back on the page it opened on" do
        admin_post("/admin/links/#{link.id}/delete", return_to: "/admin/links?sort=clicks")

        expect(last_response.location).to eq("/admin/links?sort=clicks")
      end
    end

    describe "a tag" do
      let(:tag) { create(:tag, :private, name: "home", color: "mk-blue") }

      before { get "/admin/tags/#{tag.id}/menu", scope: "private", return_to: "/admin/settings/tagging?scope=private" }

      it "holds every action a tag takes", :aggregate_failures do
        expect(menu_items).to eq(%w[Rename… Colour Pink Green Blue Violet Sand Orange Copy] + ["Delete tag"])
        expect(copies["Copy"]).to eq("#home")
      end

      it "ticks the tag's colour" do
        expect(page).to have_css("[role=menuitemcheckbox][aria-checked=true]", text: "Blue", visible: :all)
      end

      it "answers 404 for a tag in the other scope" do
        get "/admin/tags/#{tag.id}/menu", scope: "public"

        expect(last_response.status).to eq(404)
      end

      it "lands a new colour back on its section of the page it opened on", :aggregate_failures do
        back = "/admin/settings/tagging?scope=private&q=ho"
        admin_post("/admin/tags/#{tag.id}", scope: "private", tag: { name: "home", color: "mk-pink" }, return_to: back)

        expect(last_response.location).to eq("#{back}#tags")
        follow_redirect!
        expect(toast).to eq(admin_t("tags_page.toasts.recoloured"))
      end

      it "lands a delete back on its section of the page it opened on" do
        back = "/admin/settings/tagging?scope=private&q=ho"
        admin_post("/admin/tags/#{tag.id}/delete", scope: "private", return_to: back)

        expect(last_response.location).to eq("#{back}#tags")
      end

      it "lands a delete from elsewhere back where it opened" do
        admin_post("/admin/tags/#{tag.id}/delete", scope: "private", return_to: "/admin/tasks?filter=next")

        expect(last_response.location).to eq("/admin/tasks?filter=next")
      end
    end

    describe "rows" do
      it "carry the menu on the journal" do
        entry = create(:journal_entry)
        get "/admin/journal"

        expect(page).to have_css(".journal-entry[data-menu='/admin/journal/#{entry.id}/menu']")
      end

      it "carry the menu on decisions" do
        decision = create(:decision)
        get "/admin/decisions"

        expect(page).to have_css(".decision-row[data-menu='/admin/decisions/#{decision.id}/menu']")
      end

      it "carry the menu on files" do
        connect_share_store
        stub_request(:put, %r{\A#{share_store_url}/})
        file = upload_share.value!
        get "/admin/files"

        expect(page).to have_css(".file-card[data-menu='/admin/files/#{file.id}/menu']")
      end

      it "carry the menu on links" do
        link = short_link("https://example.com")
        get "/admin/links"

        expect(page).to have_css(".link-row[data-menu='/admin/links/#{link.id}/menu']")
      end

      it "carry the menu on tags" do
        tag = create(:tag, :private)
        get "/admin/settings/tagging", scope: "private"

        expect(page).to have_css(".tag-row[data-menu='/admin/tags/#{tag.id}/menu?scope=private']")
      end
    end
  end
end
