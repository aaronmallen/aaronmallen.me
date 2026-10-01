# frozen_string_literal: true

require "base64"

RSpec.describe "Admin photo upload in the Markdown editor", type: :feature do
  let(:png) { Hanami.app.root.join("spec/fixtures/photos/small.png") }
  let(:media) { Regexp.escape(Blog::Site.url("/media/")) }
  let(:photo_url) { /\A!\[\]\(#{media}[0-9a-f]{32}\.png\)\z/ }

  def body = find_field("post-body")

  def editor = find("[data-markdown-editor]:has(#post-body)")

  def hand_over(event, name, bytes, type, text: nil)
    evaluate_script(<<~JS, event, name, Base64.strict_encode64(bytes), type, text)
      (([event, name, data, type, text]) => {
        const transfer = new DataTransfer();
        transfer.items.add(new File([Uint8Array.from(atob(data), (c) => c.charCodeAt(0))], name, { type }));
        if (text) transfer.setData("text/plain", text);
        const init = { bubbles: true, cancelable: true };
        const handed = event === "drop"
          ? new DragEvent("drop", { ...init, dataTransfer: transfer })
          : new ClipboardEvent("paste", { ...init, clipboardData: transfer });
        document.getElementById("post-body").dispatchEvent(handed);
        return handed.defaultPrevented;
      })(arguments)
    JS
  end

  def hold_upload
    hold = request_gate.hold("/admin/photos")
    hand_over "drop", "small.png", png.binread, "image/png"
    hold.wait_for_arrival
    hold
  end

  def keep_puts = stub_request(:put, %r{\Ahttps://store\.example(?::443)?/photos/}).to_return(status: 200)

  def message(key) = Admin::Slice["i18n"].t(key)

  def pick = "[role='toolbar'] button[aria-label='Add a photo']"

  before { sign_in_to_admin }

  describe "with a store" do
    before do
      connect_media_store
      keep_puts
      visit "/admin/posts/new"
      fill_in "post-body", with: "Before "
    end

    it "uploads a dropped photo and puts its link at the cursor", :aggregate_failures do
      hand_over "drop", "small.png", png.binread, "image/png"

      expect(page).to have_field("post-body", with: /\ABefore !\[\]\(/)
      expect(body.value.delete_prefix("Before ")).to match(photo_url)
      expect(evaluate_script("document.getElementById('post-body').selectionStart")).to eq("Before ![".length)
    end

    it "uploads a pasted photo" do
      hand_over "paste", "small.png", png.binread, "image/png"

      expect(page).to have_field("post-body", with: /\ABefore !\[\]\(/)
    end

    it "uploads a photo picked from the toolbar", :aggregate_failures do
      expect(editor).to have_css(pick)

      editor.find("[data-editor-file]", visible: :hidden).set(png.to_s)

      expect(page).to have_field("post-body", with: /\ABefore !\[\]\(/)
    end

    it "holds a placeholder at the cursor while the photo uploads", :aggregate_failures do
      hold = hold_upload

      expect(page).to have_field("post-body", with: "Before ![Uploading small.png…]()")

      hold.release

      expect(page).to have_field("post-body", with: /\ABefore !\[\]\(/)
    end

    it "takes the placeholder out of a refused upload and says why", :aggregate_failures do
      hand_over "drop", "drawing.svg", "<svg xmlns='http://www.w3.org/2000/svg'/>", "image/svg+xml"

      expect(editor).to have_css("[role='alert']", text: message("photo_upload.errors.type"))
      expect(page).to have_field("post-body", with: "Before ")
    end

    it "leaves a paste that carries text to the browser", :aggregate_failures do
      expect(hand_over("paste", "small.png", png.binread, "image/png", text: "words")).to be(false)
      expect(body.value).to eq("Before ")
    end
  end

  describe "without a store" do
    before { visit "/admin/posts/new" }

    it "shows no upload control", :aggregate_failures do
      expect(editor).to have_no_css(pick)
      expect(editor).to have_no_css("[data-editor-file]", visible: :all)
    end

    it "ignores a dropped photo" do
      hand_over "drop", "small.png", png.binread, "image/png"

      expect(body.value).to eq("")
    end
  end
end
