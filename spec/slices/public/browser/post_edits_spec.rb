# frozen_string_literal: true

RSpec.describe "Post edit notes", type: :feature do
  def top(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().top")

  before do
    post_record = create(:post, :published, slug: "hello")
    create(:post_edit, post: post_record, note: "fixed the numbers", created_at: Time.utc(2026, 9, 7, 12))
    visit "/writing/hello"
  end

  it "puts the date on its own line above the note" do
    expect(top(".post-edit-note")).to be > top(".post-edit-date")
  end
end
