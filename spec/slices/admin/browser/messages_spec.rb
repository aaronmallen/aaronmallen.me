# frozen_string_literal: true

RSpec.describe "Admin messages", type: :feature do
  before do
    create(:message, :read, subject: "Answered")
    sign_in_to_admin
    visit "/admin/messages"
  end

  it "submits the filter once read is chosen" do
    find(".seg-option", exact_text: "read").click

    expect(page).to have_current_path("/admin/messages?status=read")
  end
end
