# frozen_string_literal: true

RSpec.describe "Admin posts tags", type: :feature do
  before do
    create(:tag, name: "ruby", color: "mk-green")
    create(:post, :published, title: "Hello", tags: %w[ruby])
    sign_in_to_admin
    visit "/admin/posts"
  end

  it "opens the tag's summary from a tag" do
    find(".post-row-meta .tag", text: "#ruby").click

    expect(page).to have_current_path("/admin/tags/ruby")
  end
end
