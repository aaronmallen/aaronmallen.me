# frozen_string_literal: true

RSpec.describe "Admin mail", type: :feature do
  let(:pane) { find(".mail-pane") }

  def long_accounts
    page.current_window.resize_to(1180, 800)
    labels = %w[receipts travel bills school family newsletters-and-other-very-long-label-names]
    %w[aaron.allen.long.address@work.example.com side.project.address@personal.example.org].each do |address|
      account = create(:mail_account, name: address, address:)
      thread = create(:message, mail_account_id: account.id, subject: "From #{address}")
      labels.each do |name|
        label = create(:mail_label, mail_account_id: account.id, name:)
        create(:mail_thread_label, mail_thread_id: thread.id, mail_label_id: label.id)
      end
    end
  end

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

  it "fits every account's labels in the folder list and keeps both panes at 1180px", :aggregate_failures do
    long_accounts
    visit "/admin/mail?thread=#{create(:message, subject: 'Open').id}"

    expect(evaluate_script("(n => n.scrollWidth - n.clientWidth)(document.querySelector('nav.mail-folders'))")).to eq(0)
    expect(evaluate_script("document.documentElement.scrollWidth - innerWidth")).to be <= 0
    expect(page).to have_css(".mail-list").and have_css(".mail-reader")
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
