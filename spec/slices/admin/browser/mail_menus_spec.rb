# frozen_string_literal: true

RSpec.describe "Admin mail menus", type: :feature do
  def open_menu(subject) = find(".mail-row-subject", text: subject).right_click

  def pick_all
    click_button "Select"
    all(".mail-row input[name='ids[]']").each(&:check)
  end

  def threads = Mail::Slice["relations.mail_threads"]

  before do
    create(:message, subject: "Newer", received_at: Time.now)
    create(:message, subject: "Older", received_at: Time.now - 60)
    sign_in_to_admin
  end

  describe "on the Mail screen" do
    before do
      visit "/admin/mail"
      keep_page
    end

    it "stars a thread from its menu in place with a toast", :aggregate_failures do
      open_menu("Older")
      item("Star").click

      expect(page).to have_css(".toast", text: "Starred 1 thread")
      expect(page).to have_css(".mail-row .fa-star", count: 1)
      expect(kept_page?).to be(true)
    end

    describe "deleting" do
      before do
        open_menu("Older")
        item("Delete").click
      end

      it "asks for a second click" do
        expect(threads.where(trashed: true).count).to eq(0)
      end

      it "moves the thread to the trash on the second click", :aggregate_failures do
        item("Click again to delete").click

        expect(page).to have_css(".toast", text: "Moved 1 thread to Trash")
        expect(page).to have_no_css(".mail-row-subject", text: "Older")
      end
    end

    it "acts on every picked thread from the bulk menu", :aggregate_failures do
      pick_all
      open_menu("Newer")
      item("Mark read").click

      expect(page).to have_css(".toast", text: "Marked 2 threads read")
      expect(threads.with_status("read").pluck(:subject)).to contain_exactly("Newer", "Older")
    end
  end

  it "archives a thread from its menu in the inbox", :aggregate_failures do
    visit "/admin/inbox"
    find(".inbox-row-title", text: "Older").right_click
    item("Archive").click

    expect(page).to have_css(".toast", text: "Archived 1 thread")
    expect(page).to have_current_path("/admin/inbox")
  end
end
