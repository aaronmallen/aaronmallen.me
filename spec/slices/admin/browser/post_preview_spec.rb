# frozen_string_literal: true

RSpec.describe "Admin post preview", type: :feature do
  let(:preview) { find("[data-post-editor] [data-editor-preview]", visible: :all) }
  let(:preview_path) { "/admin/posts/preview" }

  def previews = request_gate.count(preview_path)

  def show_view(name) = find(".edit .seg-option", text: name).click

  def type(*selectors)
    selectors.map do |selector|
      evaluate_script(<<~JS)
        (s => [s.fontFamily, s.fontSize, s.fontWeight])(getComputedStyle(document.querySelector("#{selector}")))
      JS
    end
  end

  before do
    sign_in_to_admin
    visit "/admin/posts/new"
  end

  it "renders the body typed on Write" do
    fill_in "Body", with: "Hello *there*"
    show_view "Preview"

    expect(preview).to have_css(".prose em", exact_text: "there")
  end

  it "renders the title typed on Write" do
    fill_in "Title", with: "A fresh title"
    show_view "Preview"

    expect(preview).to have_css(".post-title", exact_text: "A fresh title")
  end

  describe "for the same post as a published one" do
    let(:body) { "## Heading\n\none two" }
    let(:selectors) { [".post-title", ".prose p", ".prose h2"] }
    let!(:article) do
      create(:post, :published, slug: "hello", title: "A title", body:)
      visit "/writing/hello"
      type(*selectors)
    end

    before do
      visit "/admin/posts/new"
      fill_in "Title", with: "A title"
      fill_in "Body", with: body
      show_view "Preview"
      preview.assert_selector(".prose h2", text: "Heading")
    end

    it "sets the title and body in the public post's type" do
      expect(type(*selectors.map { ".preview #{it}" })).to eq(article)
    end
  end

  it "asks for nothing while Write is showing", :aggregate_failures do
    find_field("Body").send_keys(*"one two three".chars)

    expect(page).to have_css("[data-editor-words]", exact_text: "3 words")
    expect(previews).to eq(0)
  end

  it "asks for one preview on switching to Preview" do
    fill_in "Body", with: "one two three"
    show_view "Preview"
    preview.assert_selector(".prose", text: "one two three")

    expect(previews).to eq(1)
  end

  it "asks for nothing on switching to a Preview nothing has changed under" do
    show_view "Preview"
    show_view "Write"
    show_view "Preview"

    expect(previews).to eq(0)
  end

  it "asks for one preview for a burst of typing on Preview" do
    show_view "Preview"
    find_field("Title").send_keys(*"one two".chars)
    preview.assert_selector(".post-title", exact_text: "one two")

    expect(previews).to eq(1)
  end

  describe "when an earlier preview answers after a later one" do
    before do
      show_view "Preview"
      hold = request_gate.hold(preview_path)
      fill_in "Title", with: "stale words"
      hold.wait_for_arrival
      fill_in "Title", with: "fresh words"
      preview.assert_selector(".post-title", exact_text: "fresh words")
      hold.release
      page.driver.wait_for_network_idle
    end

    it "keeps the later preview" do
      expect(preview).to have_css(".post-title", exact_text: "fresh words")
    end
  end
end
