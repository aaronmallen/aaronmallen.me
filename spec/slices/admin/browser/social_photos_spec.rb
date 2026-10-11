# frozen_string_literal: true

require "base64"

RSpec.describe "Admin social post photos", type: :feature do
  let(:png) { Hanami.app.root.join("spec/fixtures/photos/small.png") }

  def alts = all("[data-social-part] [data-social-photo-alt]").map(&:value)

  def hand_over(event, index: 0)
    evaluate_script(<<~JS, event, index, Base64.strict_encode64(png.binread))
      (([event, index, data]) => {
        const transfer = new DataTransfer();
        transfer.items.add(new File([Uint8Array.from(atob(data), (c) => c.charCodeAt(0))], "small.png", { type: "image/png" }));
        const init = { bubbles: true, cancelable: true };
        const handed = event === "drop"
          ? new DragEvent("drop", { ...init, dataTransfer: transfer })
          : new ClipboardEvent("paste", { ...init, clipboardData: transfer });
        document.querySelectorAll("[data-social-body]")[index].dispatchEvent(handed);
      })(arguments)
    JS
  end

  def height(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().height")

  def held = Social::Slice["relations.social_post_photos"].in_order.to_a.map { it.values_at(:photo_key, :alt_text) }

  def keys = all("[data-social-part] [data-social-photo-key]", visible: :hidden).map(&:value)

  def message(key) = Admin::Slice["i18n"].t(key)

  def move_first_later = first("[data-social-photo] button[aria-label='Move later']").click

  def save_draft
    click_button "Save draft"
    find("[data-toast]")
  end

  def upload(count, index: 0)
    before = all("[data-social-photo]").size
    count.times { hand_over("drop", index:) }
    expect(page).to have_css("[data-social-photo]:not([data-social-photo-pending])", count: before + count)
  end

  before do
    connect_social_networks
    connect_media_store
    stub_request(:put, %r{\Ahttps://store\.example(?::443)?/photos/}).to_return(status: 200)
    sign_in_to_admin
    visit "/admin/social"
    find("[data-social-body]").set("hello")
  end

  it "shows a dropped photo with an alt text field", :aggregate_failures do
    upload 1

    expect(page).to have_field("Alt text")
    expect(keys.first).to match(/\A[0-9a-f]{32}\.png\z/)
  end

  it "takes a pasted photo" do
    hand_over "paste"

    expect(page).to have_field("Alt text")
  end

  it "takes a picked photo" do
    find("[data-social-photo-file]", visible: :hidden).set(png.to_s)

    expect(page).to have_field("Alt text")
  end

  it "refuses a fifth photo and says why", :aggregate_failures do
    upload 4
    hand_over "drop"

    expect(page).to have_css("[role='alert']", text: message("ui.components.social.part.photos_full"))
    expect(page).to have_css("[data-social-photo]", count: 4)
  end

  it "takes four more on a second part" do
    upload 4
    click_button "Add to thread"
    find_all("[data-social-body]", count: 2).last.set("two")
    upload 4, index: 1

    expect(page).to have_css("[data-social-photo-count]", text: "Photos 4/4", count: 2)
  end

  it "moves a photo later", :aggregate_failures do
    upload 2
    first_key = keys.first
    move_first_later

    expect(keys.last).to eq(first_key)
  end

  it "removes a photo" do
    upload 2
    first("[data-social-photo] button[aria-label='Remove photo']").click

    expect(page).to have_css("[data-social-photo]", count: 1)
  end

  it "shows the photos in the preview with their alt text" do
    upload 1
    fill_in "Alt text", with: "A small square"

    expect(page).to have_css(".compose-preview-photo[alt='A small square']")
  end

  it "saves the photos in order with their alt text" do
    upload 2
    first("[data-social-photo-alt]").set("First")
    move_first_later
    save_draft

    expect(held.map(&:last)).to eq([nil, "First"])
  end

  it "grows the photo buttons to touch size on a narrow screen" do
    page.driver.resize(375, 800)
    upload 1

    expect(height(".compose-photo-tools .bt")).to be >= 44
  end

  it "passes axe with photos on a part" do
    upload 2

    expect(axe_breaches).to be_empty
  end
end
