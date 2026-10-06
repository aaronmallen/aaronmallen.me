# frozen_string_literal: true

RSpec.describe "Contact form", type: :feature do
  let(:fields) { { "Your email" => "ada@example.com", "Subject" => "A question", "Message" => "About the beacon" } }
  let(:honeypot_right) do
    <<~JS
      document.querySelector('input[name="message[reference]"]').getBoundingClientRect().right
    JS
  end
  let(:i18n) { Public::Slice["i18n"] }
  let(:message_repo) { Contact::Slice["repos.message_repo"] }

  before { change_contact_setting(:minimum_submit_seconds, to: 0) }

  def error(key) = i18n.t(key, scope: "ui.components.contact_field_error")

  def focused = evaluate_script("document.activeElement.id")

  def send_message(changes = {})
    visit "/contact"
    fields.merge(changes).each { |label, value| fill_in(label, with: value) }
    click_button "Send message"
  end

  def stored = message_repo.by_status(Blog::Types::MessageStatus["unread"]).first

  def tab
    page.driver.browser.keyboard.type(:Tab)
    evaluate_script("document.activeElement.id || document.activeElement.tagName")
  end

  it "confirms a message that was sent, on a page of its own", :aggregate_failures do
    send_message

    expect(page).to have_current_path("/contact?sent=1")
    expect(page).to have_css(".contact .f-ok strong", text: i18n.t("ui.views.pages.contact.sent.heading"))
  end

  it "stores one message however often the page that follows is refreshed", :aggregate_failures do
    send_message
    2.times { page.refresh }

    expect(page).to have_css(".contact .f-ok strong", text: i18n.t("ui.views.pages.contact.sent.heading"))
    expect(message_repo.messages.count).to eq(1)
  end

  it "stores what was typed" do
    send_message

    expect(stored).to have_attributes(reply_to: "ada@example.com", subject: "A question", body: "About the beacon")
  end

  it "takes the message without a cookie" do
    send_message

    expect(evaluate_script("document.cookie")).to be_empty
  end

  it "tabs the three fields in order and lands on the send, never the honeypot" do
    visit "/contact"
    find_by_id("cf-email").click

    expect(Array.new(3) { tab }).to eq(%w[cf-subject cf-message BUTTON])
  end

  describe "the count under the message" do
    let(:total) { Contact::MessageLimits::MAX_BODY }

    before { visit "/contact" }

    it "shows the line the server served hidden" do
      expect(page).to have_css(".f-row p.f-h")
    end

    it "starts at nothing typed, over the total the field takes" do
      expect(page).to have_css("p.f-h", exact_text: "0 / #{total}")
    end

    it "counts what is typed" do
      fill_in "Message", with: "About the beacon"

      expect(page).to have_css("p.f-h", exact_text: "16 / #{total}")
    end

    it "counts back down when the typing is taken away" do
      fill_in "Message", with: "About the beacon"
      fill_in "Message", with: "Beacon"

      expect(page).to have_css("p.f-h", exact_text: "6 / #{total}")
    end

    it "starts at the length of what the page came back holding" do
      fill_in "Subject", with: " "
      fill_in "Your email", with: "ada@example.com"
      fill_in "Message", with: "About the beacon"
      click_button "Send message"

      expect(page).to have_css("p.f-h", exact_text: "16 / #{total}")
    end
  end

  describe "the stamp" do
    it "stores nothing from a send faster than the minimum time, and reads as sent", :aggregate_failures do
      change_contact_setting(:minimum_submit_seconds, to: Blog::Settings::DEFAULT_CONTACT_MINIMUM_SUBMIT_SECONDS)
      send_message

      expect(page).to have_css(".contact .f-ok strong", text: i18n.t("ui.views.pages.contact.sent.heading"))
      expect(message_repo.messages.count).to eq(0)
    end

    describe "on a form that sat open the minimum time" do
      before do
        change_contact_setting(:minimum_submit_seconds, to: 1)
        visit "/contact"
        fields.each { |label, value| fill_in(label, with: value) }
        sleep 1.1
        click_button "Send message"
      end

      it "stores the send", :aggregate_failures do
        expect(page).to have_current_path("/contact?sent=1")
        expect(stored).to have_attributes(subject: "A question")
      end
    end

    describe "on a form whose stamp was taken out" do
      before do
        visit "/contact"
        fields.each { |label, value| fill_in(label, with: value) }
        execute_script("document.querySelector(\"input[name='message[stamp]']\").remove()")
        click_button "Send message"
      end

      it "stores nothing, and reads as sent", :aggregate_failures do
        expect(page).to have_current_path("/contact?sent=1")
        expect(message_repo.messages.count).to eq(0)
      end
    end
  end

  it "keeps the honeypot off the screen" do
    visit "/contact"

    expect(evaluate_script(honeypot_right)).to be_negative
  end

  describe "a field the browser refuses" do
    it "names an address that is not one, and posts nothing", :aggregate_failures do
      send_message("Your email" => "ada")

      expect(page).to have_css("#cf-email-error", exact_text: error("reply_to.format"))
      expect(page).to have_current_path("/contact")
      expect(message_repo.messages.count).to eq(0)
    end

    it "asks for a subject that was left blank" do
      send_message("Subject" => "")

      expect(page).to have_css("#cf-subject-error", exact_text: error("subject.blank"))
    end

    it "asks for a message that was left blank" do
      send_message("Message" => "")

      expect(page).to have_css("#cf-message-error", exact_text: error("body.blank"))
    end

    it "leaves the fields that were filled without a message", :aggregate_failures do
      send_message("Subject" => "")

      expect(page).to have_css("#cf-subject-error")
      expect(page).to have_no_css("#cf-email-error")
      expect(page).to have_no_css("#cf-message-error")
    end

    it "points a screen reader at the message", :aggregate_failures do
      send_message("Subject" => "")

      expect(page).to have_css("#cf-subject[aria-invalid='true']")
      expect(page).to have_css("#cf-subject[aria-describedby='cf-subject-error']")
    end

    it "hands the first bad field the focus, which the cancelled bubble drops" do
      send_message("Your email" => "", "Subject" => "")

      expect(focused).to eq("cf-email")
    end

    it "clears the message once the field is put right", :aggregate_failures do
      send_message("Subject" => "")
      expect(page).to have_css("#cf-subject-error")

      fill_in("Subject", with: "A question")

      expect(page).to have_no_css("#cf-subject-error")
      expect(page).to have_no_css("#cf-subject[aria-invalid]")
    end

    it "sends the message the second time, once the field is put right", :aggregate_failures do
      send_message("Subject" => "")
      fill_in("Subject", with: "A question")
      click_button "Send message"

      expect(page).to have_current_path("/contact?sent=1")
      expect(stored).to have_attributes(subject: "A question")
    end
  end

  describe "a field the server refuses" do
    it "reads the refusal under the field" do
      send_message("Your email" => "ada@example")

      expect(page).to have_css("#cf-email-error", exact_text: error("reply_to.format"))
    end

    it "holds one message under the field, however the two arrive", :aggregate_failures do
      send_message("Your email" => "ada@example")
      fill_in("Your email", with: "")
      click_button "Send message"

      expect(page).to have_css("#cf-email-error", exact_text: error("reply_to.blank"))
      expect(page.all(".f-e[data-for='cf-email']", visible: :all).size).to eq(1)
    end
  end

  describe "with the script off" do
    before { page.driver.browser.page.disable_javascript }

    after { page.driver.browser.page.command("Emulation.setScriptExecutionDisabled", value: false) }

    it "posts the form and confirms the send", :aggregate_failures do
      send_message

      expect(page).to have_current_path("/contact?sent=1")
      expect(stored).to have_attributes(subject: "A question")
    end

    it "reads the server's refusal back, with nothing to reveal it" do
      send_message("Your email" => "ada@example")

      expect(page).to have_css("#cf-email-error", exact_text: error("reply_to.format"))
    end

    it "still refuses a blank field, with the browser's own words", :aggregate_failures do
      send_message("Subject" => "")

      expect(page).to have_no_css("#cf-subject-error")
      expect(page).to have_current_path("/contact")
      expect(message_repo.messages.count).to eq(0)
    end
  end
end
