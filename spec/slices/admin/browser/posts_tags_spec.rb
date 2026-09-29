# frozen_string_literal: true

RSpec.describe "Admin posts tags", type: :feature do
  def hash_mark = evaluate_script("getComputedStyle(document.querySelector('.li-side .post-tag'), '::before').content")

  before do
    create(:tag, name: "ruby", color: "mk-green")
    create(:post, :published, title: "Hello", tags: %w[ruby])
    sign_in_to_admin
    visit "/admin/posts"
  end

  it "reads a tag as its name after a hash mark", :aggregate_failures do
    expect(page).to have_css(".li-side .post-tag", exact_text: "ruby")
    expect(hash_mark).to eq('"#"')
  end

  it "opens the public tag page from a tag" do
    find(".li-side .post-tag", text: "ruby").click

    expect(page).to have_current_path("/writing/tags/ruby")
  end
end
