# frozen_string_literal: true

RSpec.describe "Admin mail", type: :feature do
  let(:pane) { find(".mail-pane") }

  def pick_all
    visit "/admin/mail"
    click_button "Select"
    all(".mail-row input[name='ids[]']").each(&:check)
  end

  before do
    create(:message, subject: "Newer", body: "The newer body", received_at: Time.now)
    create(:message, subject: "Older", body: "The older body", received_at: Time.now - 60)
    create(:message, :spam, subject: "Junk")
    sign_in_to_admin
  end

  after { page.current_window.resize_to(1280, 800) }

  def read = Mail::Slice["relations.mail_threads"].with_status("read").pluck(:subject)

  it "reads a thread picked from the list and marks it read", :aggregate_failures do
    visit "/admin/mail"
    find(".mail-row-open", text: "Older").click

    expect(pane).to have_css("h2", text: "Older")
    expect(page).to have_css(".mail-row.on", text: "Older")
    expect(read).to eq(%w[Older])
  end

  it "shows the folder sidebar and hides the select at 1180px and wider", :aggregate_failures do
    page.current_window.resize_to(1180, 800)
    visit "/admin/mail"

    expect(page).to have_css("nav.mail-folders")
    expect(page).to have_no_select("mail-folder")
  end

  it "swaps the sidebar for the folder select below 1180px", :aggregate_failures do
    page.current_window.resize_to(1179, 800)
    visit "/admin/mail"

    select("Spam", from: "mail-folder")
    expect(page).to have_css(".mail-row-subject", text: "Junk")
    expect(page).to have_no_css("nav.mail-folders")
  end

  it "ticks rows in Select mode and marks them read from the bar", :aggregate_failures do
    pick_all
    within("#mail-bulk") { click_button "Read" }

    expect(page).to have_css(".toast", text: "Marked 2 threads read")
    expect(read).to contain_exactly("Newer", "Older")
  end

  it "moves the ticked rows as soon as a folder is picked from the bar", :aggregate_failures do
    pick_all
    expect(page).to have_no_css("#mail-bulk button[value='move']")
    find("#mail-bulk select[name='to']").select("Spam")

    expect(page).to have_css(".toast", text: "Moved 2 threads to Spam")
  end

  it "keeps Select on screen after the reader marks a thread read", :aggregate_failures do
    visit "/admin/mail?thread=#{create(:message, subject: 'Fresh').id}"
    find(".mail-reader").click_button("Mark read")

    expect(page).to have_css(".toast", text: "Marked read")
    expect(page).to have_css("button[data-bulk-toggle][aria-pressed='false']", text: "Select")
  end
end
