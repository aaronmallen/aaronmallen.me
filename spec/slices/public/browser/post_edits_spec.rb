# frozen_string_literal: true

RSpec.describe "Post edit notes", type: :feature do
  def box(selector) = evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().toJSON()")

  before do
    post_record = create(:post, :published, slug: "hello")
    create(:post_edit, post: post_record, note: "fixed the numbers", created_at: Time.utc(2026, 9, 7, 12))
    visit "/writing/hello"
  end

  it "sets the date in a column beside the note on a wide screen" do
    page.current_window.resize_to(1200, 800)

    expect(box(".post-edit-note")["left"]).to be > box(".post-edit-date")["right"]
  end

  it "puts the date above the note on a phone" do
    page.current_window.resize_to(400, 800)

    expect(box(".post-edit-note")["top"]).to be >= box(".post-edit-date")["bottom"]
  end
end
