# frozen_string_literal: true

RSpec.describe "Admin mail sending", type: :request do
  let(:gmail) { Spec::GoogleAccounts::GMAIL }
  let(:send_scopes) { [*Spec::GoogleAccounts::GMAIL_SCOPES, "https://www.googleapis.com/auth/gmail.send"] }
  let(:work) { create(:mail_account, name: "aaron@work.example", address: "aaron@work.example") }
  let(:sent) { [] }

  def compose(**fields)
    send_mail(from: work.id, to: "ada@example.com", subject: "Engines", html: "<p>Hi</p>", **fields)
  end

  def error(key, **) = Admin::Slice["i18n"].t(key, scope: "ui.components.mail.field_error", **)

  def form_thread = create(:message, subject: "Hello", reply_to: "visitor@example.com")

  def gmail_thread
    thread = create(:message, mail_account_id: work.id, gmail_id: "t1", subject: "Engines",
                              reply_to: "ada@example.com", visitor_hash: nil)
    Mail::Slice["relations.mail_messages"].where(mail_thread_id: thread.id).update(gmail_id: "m1")
    thread
  end

  def header(name) = raw[/^#{name}: (.*?)\r$/, 1]

  def html_part = raw[%r{text/html.*?\r\n\r\n(.*?)\r\n--}m, 1].unpack1("m").force_encoding(Encoding::UTF_8)

  def no_sender(form) = Admin::Slice["i18n"].t("no_sender", scope: ["ui", "components", "mail", form])

  def page = Capybara.string(last_response.body)

  def raw = Base64.urlsafe_decode64(sent.last.fetch("raw"))

  def read_only_thread
    connect_google(account_id: "aaron@home.example", scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
    home = create(:mail_account, name: "aaron@home.example", address: "aaron@home.example")
    create(:message, mail_account_id: home.id, gmail_id: "t2", reply_to: "ada@example.com")
  end

  def send_mail(list: {}, archive: nil, **fields)
    post "/admin/mail/send", { _csrf_token: admin_csrf_token, **list, mail: { **fields, archive: }.compact }
  end

  def stored(gmail_id) = Mail::Slice["relations.mail_threads"].with(auto_struct: true).where(gmail_id:).one

  def stub_send(thread_id = "t9")
    stub_request(:post, "#{gmail}/messages/send").to_return do |request|
      sent << JSON.parse(request.body)
      google_health_json({ id: "s1", threadId: thread_id, labelIds: %w[SENT] })
    end
    stub_gmail_thread(thread_id, [gmail_message("s1", labels: %w[SENT], From: "aaron@work.example")])
  end

  before do
    sign_in_to_admin
    connect_google(account_id: work.address, scopes: send_scopes)
  end

  describe "the compose dialog" do
    it "offers every account allowed to send as From" do
      connect_google(account_id: "aaron@home.example", scopes: Spec::GoogleAccounts::GMAIL_SCOPES)
      create(:mail_account, name: "aaron@home.example", address: "aaron@home.example")
      get "/admin/mail"

      expect(page.all("#mail-compose-from option", visible: :all).map(&:text)).to eq(["aaron@work.example"])
    end

    it "leaves out an account that needs a reconnect" do
      connect_google(account_id: "aaron@home.example", scopes: send_scopes, revoked_at: Time.now)
      create(:mail_account, name: "aaron@home.example", address: "aaron@home.example")
      get "/admin/mail"

      expect(page.all("#mail-compose-from option", visible: :all).map(&:text)).to eq(["aaron@work.example"])
    end

    describe "with an account set not to send" do
      let(:home) { create(:mail_account, name: "aaron@home.example", address: "aaron@home.example") }

      before do
        connect_google(account_id: home.address, scopes: send_scopes)
        Mail::Slice["relations.mail_accounts"].where(id: home.id).update(sends: false)
      end

      it "leaves it out of From" do
        get "/admin/mail"

        expect(page.all("#mail-compose-from option", visible: :all).map(&:text)).to eq(["aaron@work.example"])
      end

      it "refuses a send from it", :aggregate_failures do
        compose(from: home.id)

        expect(page).to have_text(error("from.format"))
        invalid = "#mail-compose-from[aria-invalid='true'][aria-describedby='mail-compose-from-error']"
        expect(page).to have_css(invalid, visible: :all)
      end
    end

    describe "with no account that may send" do
      before { Mail::Slice["relations.mail_accounts"].where(id: work.id).update(sends: false) }

      it "says so in place of From on compose and reply", :aggregate_failures do
        get "/admin/mail", thread: gmail_thread.id

        expect(page).to have_no_select("mail[from]", visible: :all)
        expect(page).to have_css(".mail-head-row .mail-head-none", exact_text: no_sender("compose"), visible: :all)
        expect(page).to have_css(".mail-reply-head .mail-head-none", exact_text: no_sender("reply"), visible: :all)
      end
    end

    it "stays closed until its link asks for it", :aggregate_failures do
      get "/admin/mail"
      expect(page).to have_no_css("#mail-compose[data-dialog-show]", visible: :all)

      get "/admin/mail", compose: "1"
      expect(page).to have_css("#mail-compose[data-dialog-show]", visible: :all)
    end

    it "shows the sender's signature with a way to remove it", :aggregate_failures do
      Mail::Slice["repos.gmail_mutations"].sign(work.id, "<b>Aaron</b>")
      get "/admin/mail"

      expect(page).to have_css("#mail-compose-signature[checked]", visible: :all)
      expect(page).to have_css(".mail-sig-text b", text: "Aaron", visible: :all)
    end
  end

  describe "composing" do
    before { stub_send }

    it "says it sends through Gmail, and it does" do
      get "/admin/mail"
      shown = page.find("#mail-compose .mail-compose-hint", visible: :all).text(:all)
      compose

      expect([shown, sent.size]).to eq([Admin::Slice["i18n"].t("ui.components.mail.compose.hint"), 1])
    end

    it "sends through Gmail from the picked account in a new thread", :aggregate_failures do
      compose(to: "ada@example.com, bob@example.com", cc: "cy@example.com", bcc: "di@example.com")

      expect(%w[From To Cc Bcc Subject].map { header(it) })
        .to eq(["aaron@work.example", "ada@example.com, bob@example.com", "cy@example.com", "di@example.com",
                "Engines"])
      expect(sent.last).not_to have_key("threadId")
    end

    it "mirrors the sent thread so it shows in Sent", :aggregate_failures do
      compose
      follow_redirect!

      expect(stored("t9")).to have_attributes(sent: true, mail_account_id: work.id)
      expect(toast).to eq("Sent")
    end

    it "strips script and every attribute but a link's href", :aggregate_failures do
      compose(html: '<p onclick="x()">Hi <script>alert(1)</script><a href="https://x.example" style="c">y</a>' \
                    '<a href="javascript:alert(1)">z</a></p>')

      expect(html_part).to eq('<p>Hi <a href="https://x.example">y</a><a>z</a></p>')
    end

    it "keeps the editor's formatting", :aggregate_failures do
      formatted = "<p><b>b</b><i>i</i><u>u</u><s>s</s></p><ul><li>a</li></ul><ol><li>n</li></ol>" \
                  "<blockquote>q</blockquote><code>c</code>"
      compose(html: formatted)

      expect(html_part).to eq(formatted)
      expect(raw).to include("text/plain")
    end

    it "turns plain text into paragraphs when scripts are off" do
      compose(html: nil, body: "One\nline\n\nTwo")

      expect(html_part).to eq("<p>One<br>line</p><p>Two</p>")
    end

    it "encodes a subject beyond ASCII" do
      compose(subject: "Café")

      expect(header("Subject")).to eq("=?UTF-8?B?#{Base64.strict_encode64('Café')}?=")
    end

    it "adds the signature unless I remove it", :aggregate_failures do
      Mail::Slice["repos.gmail_mutations"].sign(work.id, "<b>Aaron</b>")

      compose(signature: "1")
      expect(html_part).to eq("<p>Hi</p><br><b>Aaron</b>")

      compose
      expect(html_part).to eq("<p>Hi</p>")
    end

    it "keeps a header on one line" do
      compose(subject: "Engines\r\nBcc: eve@example.com")

      expect(raw.scan(/^Bcc:/)).to be_empty
    end
  end

  describe "a send that can't go" do
    describe "from an account not allowed to send" do
      before do
        other = create(:mail_account, name: "aaron@home.example", address: "aaron@home.example")
        compose(from: other.id, html: "<p>Keep me</p>")
      end

      it "refuses it", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(page).to have_text(error("from.format"))
      end

      it "reopens the dialog with what I wrote", :aggregate_failures do
        expect(page).to have_css("#mail-compose[data-dialog-show]", visible: :all)
        expect(page).to have_css("input[name='mail[html]'][value='<p>Keep me</p>']", visible: :all)
      end
    end

    it "asks for a recipient and a body", :aggregate_failures do
      compose(to: "", html: "<p> </p>")

      expect(page).to have_text(error("to.blank"))
      expect(page).to have_text(error("body.blank"))
    end

    it "names the subject limit" do
      compose(subject: "a" * 201)

      expect(page).to have_text(error("subject.long", max: 200))
    end

    it "names a bad address" do
      compose(to: "ada@example.com, nobody")

      expect(page).to have_text(error("to.format"))
    end

    it "words a bad copy address as it words a bad recipient" do
      compose(cc: "nobody")

      expect(page).to have_css("#mail-compose-cc-error", text: error("to.format"), visible: :all)
    end

    it "says when Gmail refuses it" do
      stub_request(:post, "#{gmail}/messages/send").to_return(status: 500)
      compose

      expect(page).to have_text(error("send.gmail"))
    end
  end

  describe "replying" do
    let(:thread) { gmail_thread }

    def reply(**)
      send_mail(from: work.id, to: "ada@example.com", subject: "Re: Engines", html: "<p>Yes</p>",
                thread: thread.id, list: { thread: thread.id }, **)
    end

    before do
      stub_send("t1")
      stub_request(:get, %r{\A#{gmail}/messages/m1\?})
        .to_return(google_health_json({ payload: { headers: [{ name: "Message-ID", value: "<m1@mail.example>" }] } }))
    end

    it "offers a reply form addressed to the sender", :aggregate_failures do
      get "/admin/mail", thread: thread.id

      expect(page).to have_css(".mail-reply summary", text: "Reply")
      expect(page).to have_css(".mail-reply-to", text: "to ada@example.com", visible: :all)
      expect(page).to have_css(".mail-reply input[name='mail[subject]'][value='Re: Engines']", visible: :all)
    end

    it "sends in the same Gmail thread", :aggregate_failures do
      reply

      expect(sent.last["threadId"]).to eq("t1")
      expect(header("In-Reply-To")).to eq("<m1@mail.example>")
      expect(header("References")).to eq("<m1@mail.example>")
      expect(last_response.location).to end_with("thread=#{thread.id}#read-#{thread.id}")
    end

    it "archives the thread in Gmail on Send & archive", :aggregate_failures do
      modify = stub_request(:post, "#{gmail}/threads/t1/modify").with(body: { removeLabelIds: ["INBOX"] }.to_json)
      reply(archive: "1")
      follow_redirect!

      expect(modify).to have_been_requested
      expect(toast).to eq("Sent and archived")
    end

    it "counts a send Gmail took even when archiving it fails" do
      stub_request(:post, "#{gmail}/threads/t1/modify").to_return(status: 500)
      reply(archive: "1")

      expect(last_response).to be_redirect
    end

    it "keeps the reply open with what I wrote when it fails", :aggregate_failures do
      reply(html: "")

      expect(page).to have_css("details.mail-reply[open]")
      expect(page).to have_css("select#mail-reply-from.inp.auto option[selected]", text: work.address)
      expect(page).to have_no_css("#mail-compose[data-dialog-show]", visible: :all)
    end

    it "says when the thread's account can't send" do
      get "/admin/mail", thread: read_only_thread.id

      hint = "aaron@home.example can’t send · grant it on Connected services"
      expect(page).to have_css(".mail-reply-hint", text: hint, visible: :all)
    end
  end

  describe "replying to a contact form thread" do
    let(:thread) { form_thread }

    before { stub_send }

    it "says the reply goes out by email" do
      get "/admin/mail", thread: thread.id

      hint = "sent from the contact form · the reply goes out by email"
      expect(page).to have_css(".mail-reply-hint", text: hint, visible: :all)
    end

    it "emails the visitor from a Gmail account in a new thread", :aggregate_failures do
      send_mail(from: work.id, to: "visitor@example.com", subject: "Re: Hello", html: "<p>Thanks</p>",
                thread: thread.id)

      expect(header("To")).to eq("visitor@example.com")
      expect(sent.last).not_to have_key("threadId")
      expect(stored("t9")).to have_attributes(sent: true)
    end

    it "archives the form thread here on Send & archive" do
      send_mail(from: work.id, to: "visitor@example.com", subject: "Re: Hello", html: "<p>Thanks</p>",
                thread: thread.id, archive: "1")

      expect(Mail::Slice["relations.mail_threads"].by_pk(thread.id).one[:archived]).to be(true)
    end
  end
end
