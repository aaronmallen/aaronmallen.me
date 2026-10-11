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
    "http://shares.localhost/#{Shares::Slice['relations.shares'].with_code.where(filename: name).one[:code]}"
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
end
