# frozen_string_literal: true

RSpec.describe "Admin messages", type: :feature do
  let(:pane) { find(".msg-pane") }

  before do
    create(:message, subject: "Newer", body: "The newer body", received_at: Time.now)
    create(:message, subject: "Older", body: "The older body", received_at: Time.now - 60)
    sign_in_to_admin
    visit "/admin/messages"
  end

  it "reads the newest message in the pane at first", :aggregate_failures do
    expect(pane).to have_css("h2", text: "Newer")
    expect(pane).to have_no_css("h2", text: "Older")
  end

  it "reads a message picked from the list", :aggregate_failures do
    find(".msg-item-open", text: "Older").click

    expect(pane).to have_css("h2", text: "Older")
    expect(pane).to have_no_css("h2", text: "Newer")
  end
end
