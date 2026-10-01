# frozen_string_literal: true

RSpec.describe "Post edit notes", type: :feature do
  let(:post_record) { create(:post, :published, slug: "hello") }

  def style(selector, property) = evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")

  def token(name)
    evaluate_script(<<~JS)
      (() => {
        const probe = document.createElement("span");
        probe.style.color = "var(--color-#{name})";
        document.body.append(probe);
        const value = getComputedStyle(probe).color;
        probe.remove();
        return value;
      })()
    JS
  end

  def top(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().top")

  describe "a post with notes" do
    before do
      create(:post_edit, post: post_record, note: "fixed the numbers", created_at: Time.utc(2026, 9, 7, 12))
      visit "/writing/hello"
    end

    it "sets the notes apart with a divider above and below", :aggregate_failures do
      expect(style(".post-edits", "borderTopWidth")).to eq("1px")
      expect(style(".post > .eyebrow", "borderTopWidth")).to eq("1px")
    end

    it "draws the date as a kicker", :aggregate_failures do
      expect(page).to have_css(".post-edit-date", exact_text: "EDITED SEP 7, 2026")
      expect(page.find(".post-edit-date")[:class]).to eq("post-edit-date")
      expect(style(".post-edit-date", "color")).to eq(token("mk-orange-text"))
      expect(style(".post-edit-date", "textTransform")).to eq("uppercase")
    end

    it "puts the date on its own line above the note" do
      expect(top(".post-edit-note")).to be > top(".post-edit-date")
    end
  end

  it "keeps the feedback line's divider on a post with no notes", :aggregate_failures do
    post_record
    visit "/writing/hello"

    expect(page).to have_css(".post > .eyebrow")
    expect(page).to have_no_css(".post-edits")
    expect(style(".post > .eyebrow", "borderTopWidth")).to eq("1px")
  end
end
