# frozen_string_literal: true

RSpec.describe "Admin messages", type: :feature do
  let(:pane) { find(".msg-pane") }
  let(:i18n) { Admin::Slice["i18n"] }

  def read = Contact::Slice["relations.messages"].with_status("read").pluck(:subject)

  before do
    create(:message, subject: "Newer", body: "The newer body", received_at: Time.now)
    create(:message, subject: "Older", body: "The older body", received_at: Time.now - 60)
    sign_in_to_admin
    visit "/admin/messages"
  end

  it "asks for a pick at first" do
    expect(pane).to have_text(i18n.t("ui.views.messages.index.pick"))
  end

  it "reads a message picked from the list and marks it read", :aggregate_failures do
    find(".msg-item-open", text: "Older").click

    expect(pane).to have_css("h2", text: "Older")
    expect(pane).to have_no_css("h2", text: "Newer")
    expect(page).to have_no_css(".msg-item-title", text: "Older")
    expect(read).to eq(%w[Older])
  end

  it "moves the open message back to unread from the pane" do
    find(".msg-item-open", text: "Older").click
    click_button "Mark unread"

    expect(page).to have_css(".msg-item-title", text: "Older")
  end

  it "asks before it deletes from the pane", :aggregate_failures do
    find(".msg-item-open", text: "Older").click
    message = confirm_yes { pane.click_button "Delete" }

    expect(message).to eq(i18n.t("ui.components.message_letter.confirm_delete"))
    expect(page).to have_css(".toast", text: "Message deleted")
    expect(read).to be_empty
  end
end
