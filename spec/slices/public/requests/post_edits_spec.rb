# frozen_string_literal: true

RSpec.describe "Post edits", type: :request do
  subject(:page) { Capybara.string(last_response.body) }

  let(:post_record) { create(:post, :published, slug: "hello") }

  def edit(note, at:) = create(:post_edit, post: post_record, note:, created_at: at, updated_at: at)

  it "shows a note as Edit, its date and the note" do
    edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
    get "/writing/hello"

    expect(page.find(".post-edit").text(normalize_ws: true)).to eq("Edit Sep 7, 2026: fixed the numbers")
  end

  it "shows the notes above the feedback line" do
    edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
    get "/writing/hello"

    classes = page.all("article > *").map { it[:class] }

    expect(classes[classes.index("eyebrow") - 1]).to eq("post-edits")
  end

  it "dates a note by the site's day, not UTC's" do
    edit("late night fix", at: Time.utc(2026, 9, 8, 3))
    get "/writing/hello"

    expect(page.find(".post-edit-date")).to have_text("Edit Sep 7, 2026:")
  end

  describe "two notes from one day" do
    before do
      edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
      edit("fixed a link", at: Time.utc(2026, 9, 7, 15))
      get "/writing/hello"
    end

    it "shows the date once" do
      expect(page.all(".post-edit-date").map(&:text)).to eq(["Edit Sep 7, 2026:"])
    end

    it "lists the notes under it, oldest first" do
      notes = page.all(".post-edit-list .post-edit-item").map { it.text.strip }

      expect(notes).to eq(["fixed the numbers", "fixed a link"])
    end
  end

  it "shows notes from different days under their own dates, oldest first" do
    edit("fixed a link", at: Time.utc(2026, 9, 9, 12))
    edit("fixed the numbers", at: Time.utc(2026, 9, 7, 12))
    get "/writing/hello"

    expect(page.all(".post-edit").map { it.text(normalize_ws: true) })
      .to eq(["Edit Sep 7, 2026: fixed the numbers", "Edit Sep 9, 2026: fixed a link"])
  end

  it "renders the note's Markdown", :aggregate_failures do
    edit("fixed `count` and [the link](https://example.com/docs)", at: Time.utc(2026, 9, 7, 12))
    get "/writing/hello"

    expect(page).to have_css(".post-edit-note code", text: "count")
    expect(page).to have_link("the link", href: "https://example.com/docs")
  end

  it "escapes raw HTML in a note" do
    edit("fixed <script>alert(1)</script> it", at: Time.utc(2026, 9, 7, 12))
    get "/writing/hello"

    expect(page).to have_no_css(".post-edit-note script")
  end

  it "shows no notes block on a post with no notes" do
    get "/writing/hello"

    expect(page).to have_no_css(".post-edits")
  end

  it "leaves out another post's notes" do
    other = create(:post, :published, slug: "other")
    create(:post_edit, post: other, note: "fixed elsewhere")
    get "/writing/hello"

    expect(page).to have_no_css(".post-edits")
  end
end
