# frozen_string_literal: true

RSpec.describe "Admin webmentions", type: :feature do
  before do
    create(:webmention, :approved, post: create(:post, :published), author_name: "Grace")
    sign_in_to_admin
    visit "/admin/webmentions"
  end

  it "submits the filter once approved is chosen" do
    find(".seg-option", text: "approved").click

    expect(page).to have_current_path("/admin/webmentions?status=approved")
  end

  it "saves a setting turned off without a button" do
    uncheck "Receive webmentions"

    expect(page).to have_css(".toast", text: "Settings saved")
  end
end
