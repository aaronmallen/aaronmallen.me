# frozen_string_literal: true

RSpec.describe "Admin mail drafts and attachments", type: :request do
  let(:gmail) { Spec::GoogleAccounts::GMAIL }
  let(:send_scopes) { [*Spec::GoogleAccounts::GMAIL_SCOPES, "https://www.googleapis.com/auth/gmail.send"] }
  let(:work) { create(:mail_account, name: "aaron@work.example", address: "aaron@work.example") }
  let(:requests) { [] }

  def compose_value(name) = page.find("#mail-compose input[name='mail[#{name}]']", visible: :all).value

  def draft_message(labels: %w[DRAFT]) = gmail_message("d1", labels:, From: "aaron@work.example", Subject: "Plans")

  def fields(**) = { from: work.id, to: "ada@example.com", subject: "Plans", html: "<p>Go</p>", ** }

  def page = Capybara.string(last_response.body)

  def raw = Base64.urlsafe_decode64(requests.last.dig("message", "raw") || requests.last.fetch("raw"))

  def save_draft(**)
    post("/admin/mail/draft", { _csrf_token: admin_csrf_token, mail: fields(html: "<p>Soon</p>", **) })
  end

  def send_mail(**) = post("/admin/mail/send", { _csrf_token: admin_csrf_token, mail: fields(**) })

  def stored(gmail_id) = Mail::Slice["relations.mail_threads"].with(auto_struct: true).where(gmail_id:).one

  def stub_draft(verb, url)
    stub_request(verb, url).to_return do |request|
      requests << JSON.parse(request.body)
      google_health_json({ id: "r1", message: { id: "d1", threadId: "t5" } })
    end
  end

  def stub_sent(url, thread_id)
    stub_request(:post, url).to_return do |request|
      requests << JSON.parse(request.body)
      google_health_json({ id: "s1", threadId: thread_id, labelIds: %w[SENT] })
    end
  end

  before do
    sign_in_to_admin
    connect_google(account_id: work.address, scopes: send_scopes)
  end

  describe "saving a draft" do
    before do
      stub_draft(:post, "#{gmail}/drafts")
      stub_gmail_thread("t5", [draft_message])
    end

    it "saves it to Gmail and answers with its id", :aggregate_failures do
      save_draft

      expect(JSON.parse(last_response.body)).to eq("draft" => "r1")
      expect(raw).to include("To: ada@example.com", "Subject: Plans")
    end

    it "shows it in Drafts" do
      save_draft

      expect(stored("t5")).to have_attributes(draft: true)
    end

    it "updates the same draft once it has an id" do
      update = stub_draft(:put, "#{gmail}/drafts/r1")
      save_draft(draft: "r1")

      expect(update).to have_been_requested
    end

    it "starts a new draft when Gmail lost the old one" do
      stub_request(:put, "#{gmail}/drafts/gone").to_return(status: 404)
      save_draft(draft: "gone")

      expect(JSON.parse(last_response.body)).to eq("draft" => "r1")
    end

    it "refuses an account that may not send" do
      other = create(:mail_account, name: "aaron@home.example", address: "aaron@home.example")
      save_draft(from: other.id)

      expect(last_response.status).to eq(422)
    end
  end

  describe "autosaving a stored draft" do
    let(:earlier) { Time.now - 3600 }

    def messages = Mail::Slice["relations.mail_messages"].where(mail_thread_id: thread.id).order(:gmail_id).to_a

    def seed(*messages, live:)
      json = JSON.parse({ id: "t5", messages: }.to_json)
      parsed = Mail::Slice["operations.parse_gmail_thread"].call(json)
      Mail::Slice["repos.gmail_mutations"].store_thread(work.id, parsed, now: earlier)
      stub_gmail_thread("t5", live)
    end

    def thread = stored("t5")

    before do
      stub_draft(:put, "#{gmail}/drafts/r1")
      html = [gmail_part("text/html", "<p>Later</p>")]
      stub_request(:get, %r{\A#{gmail}/messages/d1\?})
        .to_return(google_health_json(gmail_message("d1", labels: %w[DRAFT], Subject: "Later", parts: html)))
    end

    it "rewrites no other message of the thread", :aggregate_failures do
      seed(gmail_message("m1"), gmail_message("d0", labels: %w[DRAFT]), live: [gmail_message("m1"), draft_message])
      save_draft(draft: "r1")

      expect(messages.map { it[:gmail_id] }).to eq(%w[d1 m1])
      expect(messages.last[:updated_at]).to be_within(1).of(earlier)
      expect(a_request(:get, %r{\A#{gmail}/threads/t5\?.*format=full})).not_to have_been_made
    end

    it "shows the latest text in Drafts", :aggregate_failures do
      seed(gmail_message("d0", labels: %w[DRAFT], Subject: "Plans"), live: [draft_message])
      save_draft(draft: "r1")

      expect(thread).to have_attributes(draft: true, subject: "Later")
      expect(messages.map { it.values_at(:gmail_id, :html_body) }).to eq([["d1", "<p>Later</p>"]])
    end
  end

  describe "opening a draft" do
    let(:thread) do
      create(:message, mail_account_id: work.id, gmail_id: "t5", subject: "Plans", visitor_hash: nil)
        .tap { Mail::Slice["relations.mail_threads"].where(id: it.id).update(draft: true) }
    end

    before do
      stub_request(:get, %r{\A#{gmail}/drafts\?})
        .to_return(google_health_json({ drafts: [{ id: "r1", message: { id: "d1", threadId: "t5" } }] }))
      html = [gmail_part("text/html", "<p>Soon</p>")]
      message = gmail_message("d1", labels: %w[DRAFT], To: "ada@example.com", Cc: "cy@example.com", parts: html)
      stub_request(:get, %r{\A#{gmail}/drafts/r1\?}).to_return(google_health_json({ id: "r1", message: }))
    end

    it "asks Gmail for nothing until the owner opens the editor", :aggregate_failures do
      get "/admin/mail", thread: thread.id

      expect(a_request(:get, %r{\A#{gmail}/drafts})).not_to have_been_made
      expect(Rack::Utils.parse_query(URI(page.find_link("Edit draft")[:href]).query))
        .to include("thread" => thread.id.to_s, "resume" => "1")
      expect(page).to have_no_css("#mail-compose[data-dialog-show]", visible: :all)
    end

    it "resumes it in compose", :aggregate_failures do
      get "/admin/mail", thread: thread.id, resume: "1"

      expect(page).to have_css("#mail-compose[data-dialog-show]", visible: :all)
      expect(%w[draft to cc subject html].map { compose_value(it) })
        .to eq(["r1", "ada@example.com", "cy@example.com", "Engines", "<p>Soon</p>"])
    end

    it "sends it through the draft so it leaves Drafts", :aggregate_failures do
      stub_sent("#{gmail}/drafts/send", "t5")
      stub_gmail_thread("t5", [draft_message(labels: %w[SENT])])
      send_mail(draft: "r1")

      expect(requests.last["id"]).to eq("r1")
      expect(stored("t5")).to have_attributes(draft: false, sent: true)
    end

    it "sends anew when Gmail lost the draft" do
      stub_request(:post, "#{gmail}/drafts/send").to_return(status: 404)
      fresh = stub_sent("#{gmail}/messages/send", "t9")
      stub_gmail_thread("t9", [gmail_message("s1", labels: %w[SENT])])
      send_mail(draft: "gone")

      expect(fresh).to have_been_requested
    end
  end

  describe "sending an attachment" do
    before do
      stub_sent("#{gmail}/messages/send", "t9")
      stub_gmail_thread("t9", [gmail_message("s1", labels: %w[SENT])])
    end

    it "carries the file in the message", :aggregate_failures do
      send_mail(files: [Rack::Test::UploadedFile.new(StringIO.new("one,two\n"), original_filename: 'plan "v2".csv')])

      expect(raw).to include("multipart/mixed", 'Content-Disposition: attachment; filename="plan _v2_.csv"')
      expect(raw[/filename="plan _v2_.csv"\r\nContent-Transfer-Encoding: base64\r\n\r\n(\S+)/, 1].unpack1("m"))
        .to eq("one,two\n")
    end
  end

  describe "a received attachment" do
    let(:parts) do
      pdf = { partId: "1", mimeType: "application/pdf", filename: "deck.pdf", headers: [],
              body: { attachmentId: "a1", size: 2048 } }
      [gmail_part("text/plain", "See attached"), pdf]
    end

    before do
      stub_gmail(history: ["t3"], threads: { "t3" => [gmail_message("m3", parts:)] })
      Mail::Slice["repos.gmail_mutations"].follow(work.id, "100")
      Mail::Slice["operations.sync_gmail"].call
    end

    def message = Mail::Slice["relations.mail_messages"].where(gmail_id: "m3").one

    def stub_download
      stub_request(:get, %r{\A#{gmail}/messages/m3\?}).to_return(google_health_json(gmail_message("m3", parts:)))
      stub_request(:get, "#{gmail}/messages/m3/attachments/a1")
        .to_return(google_health_json({ data: Base64.urlsafe_encode64("%PDF") }))
    end

    it "lists on its message" do
      get "/admin/mail", thread: stored("t3").id

      expect(page).to have_link("deck.pdf", href: "/admin/mail/messages/#{message[:id]}/attachments/1")
    end

    it "downloads from Gmail", :aggregate_failures do
      stub_download
      get "/admin/mail/messages/#{message[:id]}/attachments/1"

      expect(last_response.body).to eq("%PDF")
      expect(last_response.headers["content-disposition"]).to start_with('attachment; filename="deck.pdf"')
    end

    it "answers 404 for a part it never listed" do
      get "/admin/mail/messages/#{message[:id]}/attachments/9"

      expect(last_response.status).to eq(404)
    end
  end
end
