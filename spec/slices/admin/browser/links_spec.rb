# frozen_string_literal: true

RSpec.describe "Admin links", type: :feature do
  let(:i18n) { Admin::Slice["i18n"] }

  def again_hint = i18n.t("ui.views.links.index.again", link: "shares.localhost/talk-now")

  def code = Shares::Slice["relations.short_links"].with_code.one[:code]

  def copied = page.evaluate_script("window.copiedKeys")

  def shorten(destination, code: nil)
    fill_in "Long link", with: destination
    fill_in "Short code · optional", with: code if code
    click_button "Shorten"
  end

  def talk
    Shares::Slice["operations.create_short_link"].call({ destination: "https://example.com/talk", code: "talk-now" })
  end

  def watch_clipboard_items
    watch_clipboard
    execute_script(<<~JS)
      navigator.clipboard.write = async (items) => {
        for (const item of items) window.copiedKeys.push(await (await item.getType("text/plain")).text());
      };
    JS
  end

  before do
    sign_in_to_admin
    visit "/admin/links"
    watch_clipboard_items
  end

  it "shortens a link, copies it and lists it", :aggregate_failures do
    shorten("https://example.com/talk")

    expect(page).to have_css(".toast", text: "Shortened · link copied")
    expect(page).to have_css(".link-row-title", exact_text: "example.com")
    expect(copied).to eq(["http://shares.localhost/#{code}"])
    expect(find_field("Long link").value).to be_empty
  end

  it "names a link I shortened before without copying", :aggregate_failures do
    talk
    shorten("https://example.com/talk")

    expect(page).to have_css(".link-new .hint", text: again_hint)
    expect(copied).to be_empty
  end

  it "makes a second when I shorten a link again", :aggregate_failures do
    talk.then { shorten("https://example.com/talk") }
    find(".link-new .hint").then { click_button "Shorten" }

    expect(page).to have_css(".link-row", count: 2)
    expect(copied.size).to eq(1)
  end

  it "shows a refused code beside its field without copying", :aggregate_failures do
    shorten("https://example.com/talk", code: "no--way")

    expect(page).to have_css("#link-code-error", text: i18n.t("ui.components.links.field_error.code.format"))
    expect(copied).to be_empty
  end

  it "copies a row's link from its chip", :aggregate_failures do
    talk
    visit("/admin/links").then { watch_clipboard_items }
    find(".link-chip").click

    expect(page).to have_css(".toast", text: "Link copied")
    expect(copied).to eq(["http://shares.localhost/talk-now"])
  end

  describe "hovering a row" do
    before do
      talk
      visit "/admin/links"
    end

    it "pinks its title" do
      find(".link-row").hover

      expect(color_of(find(".link-row-title"))).to eq(accent_text)
    end

    it "pinks its open icon" do
      find(".link-row-acts .bt.gh").hover

      expect(color_of(find(".link-row-acts .bt.gh > i"))).to eq(accent_text)
    end
  end

  describe "a row's drawer" do
    def drawer(&) = within("dialog[open].file-drawer", &)

    before do
      talk
      visit("/admin/links").then { watch_clipboard_items }
      find(".link-row").click
    end

    it "opens when I click the row" do
      expect(page).to have_css("dialog[open].file-drawer .file-drawer-name", text: "example.com")
    end

    it "copies the link as markdown with the host", :aggregate_failures do
      drawer { click_button "Copy as markdown" }

      expect(page).to have_css(".toast", text: "Markdown copied")
      expect(copied).to eq(["[example.com](http://shares.localhost/talk-now)"])
    end

    it "keeps text I closed it on when I shorten another link" do
      drawer { fill_in("Title", with: "My talk").then { send_keys(:escape) } }
      shorten("https://example.com/other")
      assert_selector(".link-row", count: 2)
      find(".link-row", text: "/talk").click

      drawer { expect(page).to have_field("Title", with: "My talk") }
    end

    it "saves a new title" do
      drawer { fill_in("Title", with: "My talk").then { click_button "Save" } }

      expect(page).to have_css(".link-row-title", exact_text: "My talk")
    end

    describe "deleting" do
      before { drawer { click_button "Delete link" } }

      it "asks first" do
        confirm = i18n.t("ui.components.links.link_form.confirm_delete", link: "shares.localhost/talk-now")

        expect(page).to have_css("[data-confirm-message]", text: confirm)
      end

      it "removes the row once I say yes" do
        drawer { click_button "Delete link" }

        expect(page).to have_no_css(".link-row")
      end
    end
  end
end
