# frozen_string_literal: true

RSpec.describe "Writing list", type: :feature do
  before do
    create(:tag, name: "ruby", color: "mk-violet")
    create(
      :post,
      :published,
      body: "word " * 440,
      published_at: Time.utc(2026, 9, 7, 12),
      slug: "hello",
      summary: "One line and no more",
      tags: %w[ruby],
      title: "Hello",
    )
    visit "/writing"
  end

  it "reads the date, the tag and the reading time down the meta column" do
    expect(page.find(".entry-meta").all(:xpath, "./*").map(&:text)).to eq(["Sep 7, 2026", "ruby", "2 min"])
  end
end
