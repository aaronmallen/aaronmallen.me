# frozen_string_literal: true

require "base64"

RSpec.describe "Admin files", type: :feature do
  def copied = page.evaluate_script("window.copiedKeys")

  def drop(*files)
    evaluate_script(<<~JS, files.map { |(name, bytes, type)| [name, Base64.strict_encode64(bytes), type] })
      (([files]) => {
        const transfer = new DataTransfer();
        for (const [name, data, type] of files) {
          transfer.items.add(new File([Uint8Array.from(atob(data), (c) => c.charCodeAt(0))], name, { type }));
        }
        document.querySelector("[data-file-drop]")
          .dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: transfer }));
      })(arguments)
    JS
  end

  def link(name)
    "http://shares.localhost/#{Shares::Slice['relations.shares'].with_code.where(filename: name).one[:short]}"
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
    connect_share_store
    stub_request(:put, %r{\A#{share_store_url}/})
    visit "/admin/files"
    watch_clipboard_items
  end

  it "uploads one dropped file and copies its link", :aggregate_failures do
    drop(["deck.pdf", "%PDF-1.7", "application/pdf"])

    expect(page).to have_css(".toast", text: "Uploaded · link copied")
    expect(page).to have_css(".file-card-name", exact_text: "deck.pdf")
    expect(copied).to eq([link("deck.pdf")])
  end

  it "uploads every dropped file without copying", :aggregate_failures do
    drop(["a.txt", "a", "text/plain"], ["b.zip", "PK", "application/zip"])

    expect(page).to have_css(".toast", text: "2 files uploaded")
    expect(page.all(".file-card-name").map(&:text)).to contain_exactly("a.txt", "b.zip")
    expect(copied).to be_empty
  end

  it "uploads a file chosen in the picker" do
    find_field("files[]").set(Hanami.app.root.join("spec/fixtures/photos/small.png").to_s)

    expect(page).to have_css(".toast", text: "Uploaded · link copied")
  end

  it "copies a card's link", :aggregate_failures do
    drop(["deck.pdf", "%PDF-1.7", "application/pdf"])
    within(".file-card") { click_button "Copy link" }

    expect(page).to have_css(".toast", text: "Link copied")
    expect(copied).to eq([link("deck.pdf")] * 2)
  end

  it "pinks a card's open icon on hover" do
    drop(["deck.pdf", "%PDF-1.7", "application/pdf"])
    find(".file-card-acts .bt.gh").hover

    expect(color_of(find(".file-card-acts .bt.gh > i"))).to eq(accent_text)
  end

  describe "a card's drawer" do
    def drawer(&) = within("dialog[open].file-drawer", &)

    def open_card(name) = find(".file-card", text: name).click

    def save_alt_text(text)
      drop(["shot.png", "png", "image/png"])
      open_card("shot.png")
      drawer { fill_in("Alt text", with: text).then { click_button "Save" } }
      find(".toast", text: "File saved")
      watch_clipboard_items
    end

    it "opens when I click the card" do
      drop(["deck.pdf", "%PDF-1.7", "application/pdf"])
      open_card("deck.pdf")

      expect(page).to have_css("dialog[open].file-drawer .file-drawer-name", text: "deck.pdf")
    end

    it "copies an image as markdown with the alt text I saved", :aggregate_failures do
      save_alt_text("A cat")
      open_card("shot.png")
      drawer { click_button "Copy as markdown" }

      expect(page).to have_css(".toast", text: "Markdown copied")
      expect(copied).to eq(["![A cat](#{link('shot.png')})"])
    end

    describe "after another upload" do
      before do
        drop(["shot.png", "png", "image/png"])
        open_card("shot.png")
        drawer { fill_in("Alt text", with: "A cat").then { send_keys(:escape) } }
        drop(["deck.pdf", "%PDF-1.7", "application/pdf"])
        find(".file-card-name", exact_text: "deck.pdf")
      end

      it "keeps text I closed it on" do
        open_card("shot.png")

        drawer { expect(page).to have_field("Alt text", with: "A cat") }
      end
    end

    describe "deleting" do
      before do
        drop(["deck.pdf", "%PDF-1.7", "application/pdf"])
        stub_request(:delete, %r{\A#{share_store_url}/})
        open_card("deck.pdf")
        drawer { click_button "Delete file" }
      end

      it "asks first" do
        confirm = Admin::Slice["i18n"].t("ui.components.files.share_form.confirm_delete", name: "deck.pdf")

        expect(page).to have_css("[data-confirm-message]", text: confirm)
      end

      it "removes the card once I say yes" do
        drawer { click_button "Delete file" }

        expect(page).to have_no_css(".file-card")
      end
    end
  end
end
