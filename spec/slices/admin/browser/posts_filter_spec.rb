# frozen_string_literal: true

RSpec.describe "Admin posts filter", type: :feature do
  before do
    create(:post, :draft, title: "A draft")
    sign_in_to_admin
    visit "/admin/posts"
  end

  it "submits the filter once drafts is chosen" do
    find(".seg-option", text: "drafts").click

    expect(page).to have_current_path("/admin/posts?status=draft")
  end

  it "redraws the list without loading the page" do
    page.execute_script("window.stayed = true")
    find(".seg-option", text: "drafts").click
    page.assert_current_path("/admin/posts?status=draft")

    expect(page.evaluate_script("window.stayed")).to be(true)
  end
end
