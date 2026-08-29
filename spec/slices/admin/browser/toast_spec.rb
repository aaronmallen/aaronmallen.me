# frozen_string_literal: true

RSpec.describe "Admin toast", type: :feature do
  before do
    sign_in_to_admin
    visit "/admin/posts/new"
    fill_in "Title", with: "Hello"
    click_button "Save draft"
  end

  it "shows the toast after the redirect" do
    expect(page).to have_css(".toast", text: "Draft saved")
  end

  it "takes the toast away after it has shown" do
    page.assert_selector(".toast", text: "Draft saved")

    expect(page).to have_no_css("[data-toast]", visible: :all, wait: 5)
  end
end
