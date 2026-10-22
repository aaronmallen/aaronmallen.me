# frozen_string_literal: true

RSpec.describe "Admin mail settings", type: :request do
  let(:work) { create(:mail_account, name: "aaron@work.example", address: "aaron@work.example") }

  def gmail(*, sender: "someone@example.com", **) = create(:message, *, mail_account_id: work.id, reply_to: sender, **)

  def inbox
    get "/admin/inbox"
    page.all("[data-key-list] .inbox-row-title").map(&:text)
  end

  def labeled(thread, name)
    label = create(:mail_label, mail_account_id: work.id, name:)
    create(:mail_thread_label, mail_thread_id: thread.id, mail_label_id: label.id)
  end

  def mail
    get "/admin/mail"
    page.all(".mail-row-subject").map { it.text.sub(/ · \d+\z/, "") }
  end

  def save(**) = post("/admin/mail/settings", { _csrf_token: admin_csrf_token, ** })

  def why(thread)
    get "/admin/inbox"
    page.find("#message-#{thread.id}").text
  end

  it "sends a visitor who isn't signed in to sign in" do
    get "/admin/mail/settings"

    expect(last_response).to be_redirect
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "links to the settings from Mail" do
      get "/admin/mail"

      expect(page).to have_link("Mail settings", href: "/admin/mail/settings")
    end

    describe "the accounts" do
      let(:form) { Mail::Slice["relations.mail_accounts"].contact_form_id }

      before do
        work
        create(:message)
        get "/admin/mail/settings"
      end

      it "shows and sends from each Gmail account", :aggregate_failures do
        expect(page).to have_field("accounts[#{work.id}][shown]", checked: true)
        expect(page).to have_field("accounts[#{work.id}][sends]", checked: true)
      end

      it "says it picks which accounts show and send, and which threads reach Waiting", :aggregate_failures do
        expect(page).to have_css(".page-head-sub", exact_text: Admin::Slice["i18n"].t("ui.views.mail.settings.sub"))
        expect(page).to have_field("accounts[#{work.id}][shown]").and have_field("accounts[#{work.id}][sends]")
        expect(page).to have_field("settings[needs_reply]")
      end

      it "only shows the contact form", :aggregate_failures do
        expect(page).to have_field("accounts[#{form}][shown]", checked: true)
        expect(page).to have_no_field("accounts[#{form}][sends]")
      end
    end

    it "posts the settings when one changes", :aggregate_failures do
      get "/admin/mail/settings"

      expect(page).to have_css("form[method='post'][action='/admin/mail/settings'][data-autosubmit]")
      expect(page.find("form[data-autosubmit]")).to have_field("_csrf_token", type: :hidden)
    end

    it "shows the default rules without writing a settings row", :aggregate_failures do
      get "/admin/mail/settings"

      expect(page).to have_field("settings[starred]", checked: true)
      expect(page).to have_field("settings[important]", checked: false)
      expect(Mail::Slice["relations.mail_settings"].count).to eq(0)
    end

    it "saves and says so", :aggregate_failures do
      save(settings: { important: "1" })
      follow_redirect!

      expect(page).to have_field("settings[important]", checked: true)
      expect(page).to have_css("[data-toast] .toast", text: "Mail settings saved", visible: :all)
    end

    it "keeps an account from sending" do
      save(accounts: { work.id => { shown: "1", sends: "0" } })

      expect(Mail::Slice["repos.thread_queries"].every_account).to contain_exactly(have_attributes(sends: false))
    end

    describe "an account turned off" do
      before do
        gmail(subject: "Starred at work", starred: true)
        create(:message, subject: "From the form")
        save(accounts: { work.id => { shown: "0" } })
      end

      it "hides its threads from Mail and Waiting", :aggregate_failures do
        expect(mail).to eq(["From the form"])
        expect(inbox).to eq(["From the form"])
      end

      it "drops out of the account picker" do
        get "/admin/mail"

        expect(page).to have_no_select("account", with_options: ["aaron@work.example"])
      end

      it "comes back when turned on" do
        save(accounts: { work.id => { shown: "1" } })

        expect(inbox).to contain_exactly("Starred at work", "From the form")
      end
    end

    describe "the waiting count" do
      before do
        create(:message, subject: "First")
        create(:message, subject: "Second")
        create(:message, :read, subject: "Read")
      end

      it "counts the threads that wait now" do
        waiting = inbox
        get "/admin/mail/settings"

        expect([waiting.sort, page.find("#mail-waiting .hint").text])
          .to eq([%w[First Second], Admin::Slice["i18n"].t("ui.views.mail.settings.waiting_hint", count: 2)])
      end
    end

    describe "the Waiting rules" do
      let(:matches) do
        {
          contact_form: -> { create(:message, subject: "Hello") },
          people: lambda {
            create(:person, name: "Countess of Lovelace", emails: [{ value: "ada@example.com" }])
            gmail(subject: "Hello", from_name: "Ada Lovelace", sender: "ADA@example.com")
          },
          needs_reply: -> { gmail(subject: "Hello").tap { labeled(it, "needs-reply") } },
          starred: -> { gmail(:read, subject: "Hello", starred: true) },
        }
      end

      {
        contact_form: "contact form", people: "from Contacts", needs_reply: "label: needs-reply", starred: "starred",
      }.each do |rule, reason|
        it "puts a thread in Waiting by #{rule} and says why", :aggregate_failures do
          thread = matches.fetch(rule).call

          expect(inbox).to eq(["Hello"])
          expect(why(thread)).to include(reason)
        end

        it "leaves the thread out once #{rule} is off" do
          matches.fetch(rule).call
          save(settings: { rule => "0" })

          expect(inbox).to be_empty
        end
      end

      it "leaves Gmail's important mail out until its rule is on", :aggregate_failures do
        thread = gmail(subject: "Hello", important: true)
        expect(inbox).to be_empty

        save(settings: { important: "1" })
        expect(inbox).to eq(["Hello"])
        expect(why(thread)).to include("Gmail: important")
      end

      it "leaves unread mail that matches no rule on Mail alone", :aggregate_failures do
        gmail(subject: "Just mail")

        expect(inbox).to be_empty
        expect(mail).to eq(["Just mail"])
      end

      it "leaves out a sender who shares a contact's name but not an email" do
        create(:person, name: "Ada Lovelace", emails: [{ value: "ada@example.com" }])
        gmail(subject: "Hello", from_name: "Ada Lovelace", sender: "imposter@example.com")

        expect(inbox).to be_empty
      end

      it "leaves an archived starred thread out" do
        gmail(subject: "Hello", starred: true, archived: true)

        expect(inbox).to be_empty
      end

      %w[
        notifications@github.com notifications@linear.app comments-noreply@docs.google.com
        drive-shares-dm-noreply@google.com
      ].each do |sender|
        it "skips a notification from #{sender} until told not to", :aggregate_failures do
          gmail(subject: "Hello", sender:, starred: true)
          expect(inbox).to be_empty

          save(settings: { skip_notifications: "0" })
          expect(inbox).to eq(["Hello"])
        end
      end
    end

    describe "the counts" do
      before do
        gmail(subject: "Starred", starred: true)
        gmail(subject: "Just mail")
        create(:message, subject: "From the form")
        get "/admin"
      end

      it "matches Waiting in the nav and on Today's Needs attention", :aggregate_failures do
        expect(page).to have_css("#command-palette-inbox .pal-r-sub", exact_text: "2 waiting", visible: :all)
        attention = page.find("section.card[data-attention]")
        expect(attention.find(".today-line", text: "Inbox")).to have_text("2 waiting →")
        expect(inbox).to have(2).items
      end
    end
  end
end
