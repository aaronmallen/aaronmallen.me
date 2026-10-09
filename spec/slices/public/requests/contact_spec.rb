# frozen_string_literal: true

require "digest"

RSpec.describe "Contact", type: :request do
  let(:fields) { { reply_to: "ada@example.com", subject: "A question", body: "About the beacon" } }
  let(:i18n) { Public::Slice["i18n"] }
  let(:message_queries) { Contact::Slice["repos.message_queries"] }
  let(:page) { Capybara.string(last_response.body) }

  def copy(key) = i18n.t(key, scope: "ui.views.pages.contact")

  def error(key) = i18n.t(key, scope: "ui.components.contact_field_error")

  def info(key) = i18n.t(key, scope: "ui.components.contact_info")

  def send_from(headers) = post("/contact", { message: stamped(fields) }, headers)

  def send_message(**changes) = post("/contact", message: stamped(fields.merge(changes)))

  def sent_path = "/contact?sent=1"

  def stored = message_queries.by_status(Blog::Types::MessageStatus["unread"])

  describe "the page" do
    before { get "/contact" }

    it "titles the page" do
      expect(page.title).to eq("Contact | Aaron Allen")
    end

    it "heads the page with a kicker over the heading", :aggregate_failures do
      expect(page).to have_css(".hd .kicker", exact_text: copy("kicker"))
      expect(page).to have_css(".hd h1", exact_text: copy("heading"))
    end

    it "opens with a lede" do
      expect(page).to have_css(".hd p.ld", exact_text: copy("lede"))
    end

    it "sets the head and info list beside the form, in the even grid", :aggregate_failures do
      expect(page).to have_css(".g.even > .stick > .hd + dl.ci")
      expect(page).to have_css(".g.even > .stick + div > form.form.card")
    end

    it "lists where Aaron is, what he works on, what the site keeps and where else he is" do
      headings = page.all("dl.ci dt.kicker").map(&:text)

      expect(headings).to eq(%w[where work keep elsewhere].map { info("#{it}.heading") })
    end

    it "says where Aaron is, with the zone in the clock's slot", :aggregate_failures do
      expect(page).to have_css(".ci-v", exact_text: info("where.value"))
      expect(page).to have_css(
        ".ci-s [data-clock='#{Blog::TimeZone::NAME}'][data-clock-label='#{info('where.clock')}']",
        exact_text: info("where.zone"),
      )
    end

    it "links what Aaron works on through the site's own pages", :aggregate_failures do
      expect(page).to have_link(info("work.employer"), href: "/about")
      expect(page).to have_link(info("work.hanakai"), href: "https://hanakai.org")
      expect(page).to have_link(info("work.projects"), href: "/projects")
    end

    it "says what the site keeps, linked to the privacy page", :aggregate_failures do
      expect(page).to have_css(".ci-v", exact_text: info("keep.value"))
      expect(page).to have_css(".ci-s", text: info("keep.detail").strip)
      expect(page).to have_link(info("keep.privacy"), href: "/privacy")
    end

    it "lists the profiles the settings hold as pills" do
      profiles = %i[github mastodon bluesky].map { Hanami.app.settings.public_send(it)[:profile_url] }

      expect(page.all(".ci ul.links a").map { it[:href] }).to eq(profiles)
    end

    it "posts the form back to /contact", :aggregate_failures do
      expect(page).to have_css("form.form[method='post'][action='/contact']")
      expect(page.all("form").size).to eq(1)
    end

    it "names the form, which the scripts that come later attach to" do
      expect(page).to have_css("form##{Public::UI::Views::Pages::Contact::FORM_ID}")
    end

    it "labels a reply address, a subject and a message", :aggregate_failures do
      expect(page).to have_field(copy("fields.reply_to"), type: "email")
      expect(page).to have_field(copy("fields.subject"))
      expect(page).to have_field(copy("fields.body"))
    end

    it "orders the three fields the way they are read" do
      expect(page.all("form .f-row .f-i").map { it[:name] })
        .to eq(["message[reply_to]", "message[subject]", "message[body]"])
    end

    it "marks all three required, so the browser speaks before the server has to" do
      expect(page.all("form .f-row .f-i[required]").size).to eq(3)
    end

    it "prompts each field with a placeholder", :aggregate_failures do
      expect(page.find_by_id("cf-email")[:placeholder]).to eq(copy("placeholders.reply_to"))
      expect(page.find_by_id("cf-subject")[:placeholder]).to eq(copy("placeholders.subject"))
      expect(page.find_by_id("cf-message")[:placeholder]).to eq(copy("placeholders.body"))
    end

    it "caps the subject and the message at the length the contract takes", :aggregate_failures do
      expect(page).to have_css("#cf-subject[maxlength='#{Contact::Types::MAX_SUBJECT}']")
      expect(page).to have_css("#cf-message[maxlength='#{Contact::Types::MAX_BODY}']")
    end

    describe "the count under the message" do
      it "follows the message it counts", :aggregate_failures do
        expect(page).to have_css("#cf-message + p.f-h", visible: :all)
        expect(page).to have_css("p.f-h[data-count-for='cf-message']", visible: :all)
      end

      it "leaves a slot for the count and one for the total", :aggregate_failures do
        expect(page).to have_css("p.f-h > span[data-count]", visible: :all)
        expect(page).to have_css("p.f-h > span[data-total]", visible: :all)
      end

      it "prints neither number, since the field's own maxlength is the total", :aggregate_failures do
        markup = page.find("p.f-h", visible: :all).native.to_html

        expect(markup).to include("data-total")
        expect(markup).not_to match(/\d/)
      end

      it "stays hidden for a sender whose browser runs no script" do
        expect(page).to have_css("p.f-h[hidden]", visible: :all)
      end
    end

    it "leaves the three fields in the natural tab order" do
      expect(page).to have_no_css("form .f-row .f-i[tabindex]")
    end

    it "offers a submit, under an icon that reads out as nothing", :aggregate_failures do
      expect(page).to have_button(copy("send"), type: "submit")
      expect(page).to have_css("button.f-b > i.fa-paper-plane[aria-hidden='true']")
    end

    it "notes where the message goes, beside the submit" do
      expect(page).to have_css(".f-a .f-n", exact_text: copy("note"))
    end

    it "carries no CSRF token, because there is no privilege to forge", :aggregate_failures do
      expect(page).to have_no_field("_csrf_token", type: :hidden)
      expect(last_response.headers["set-cookie"]).to be_nil
    end

    it "shows no error before anything is sent" do
      expect(page).to have_no_css(".f-e")
    end

    it "leaves the browser's own checking on, since it is what refuses a bad field" do
      expect(page).to have_no_css("form[novalidate]")
    end

    it "holds one hidden slot under each field, for the browser to fill" do
      expect(page.all(".f-e", visible: :hidden).map { it[:"data-for"] }).to eq(%w[cf-email cf-subject cf-message])
    end

    it "hands the browser the copy the server sends, rather than a second wording", :aggregate_failures do
      slot = ->(id) { page.find_by_id(id, visible: :hidden) }

      expect(slot["cf-email-error"][:"data-blank"]).to eq(error("reply_to.blank"))
      expect(slot["cf-email-error"][:"data-format"]).to eq(error("reply_to.format"))
      expect(slot["cf-subject-error"][:"data-blank"]).to eq(error("subject.blank"))
      expect(slot["cf-message-error"][:"data-blank"]).to eq(error("body.blank"))
    end

    it "reads out no address to write to but the placeholder's", :aggregate_failures do
      expect(last_response.body).not_to include("mailto:")
      expect(last_response.body.scan(/[\w.+-]+@[\w-]+\.[a-z]{2,}/i).uniq)
        .to contain_exactly(copy("placeholders.reply_to"))
    end

    describe "the honeypot" do
      subject(:honeypot) { page.find("input[name='message[reference]']", visible: :all) }

      let(:trap) { page.find(".f-hp", visible: :all) }

      it "is a text field, not a hidden one" do
        expect(honeypot[:type]).to eq("text")
      end

      it "sits outside the tab order" do
        expect(honeypot[:tabindex]).to eq("-1")
      end

      it "takes its label and its field out of the accessibility tree together" do
        expect(trap["aria-hidden"]).to eq("true")
      end

      it "asks no password manager to fill it" do
        expect(honeypot[:autocomplete]).to eq("off")
      end

      it "is styled out rather than laid out" do
        expect(trap[:class]).to include("f-hp")
      end

      it "baits a bot with a label a person never reads" do
        expect(trap.find("label", visible: :all)[:for]).to eq(honeypot[:id])
      end
    end
  end

  describe "the page after a send" do
    before { get(sent_path) }

    it "answers with the page" do
      expect(last_response).to be_ok
    end

    it "confirms the message", :aggregate_failures do
      expect(page).to have_css(".f-ok strong", exact_text: copy("sent.heading"))
      expect(page).to have_css(".f-ok p", exact_text: copy("sent.body"))
    end

    it "reads as a send that went through", :aggregate_failures do
      expect(page).to have_css(".f-ok > i.fa-circle-check[aria-hidden='true']")
      expect(page).to have_no_css(".f-ok.f-wait")
    end

    it "offers no form to send again" do
      expect(page).to have_no_css("form")
    end

    it "stores nothing, since anyone can ask for it" do
      expect(message_queries.messages.count).to eq(0)
    end

    it "ends at the answer, with no other way to write" do
      expect(page).to have_no_css(".post-body")
    end

    it "keeps the head and the info list", :aggregate_failures do
      expect(page).to have_css(".stick .hd h1", exact_text: copy("heading"))
      expect(page).to have_css(".stick dl.ci .ci-r", count: 4)
    end
  end

  describe "the page asked for with a query string that names the view's input" do
    it "shows the form rather than the refusal a throttled send gets", :aggregate_failures do
      get "/contact?throttled=1"

      expect(page).to have_css("form")
      expect(page).to have_no_css(".f-ok")
    end

    it "shows no error the server never found", :aggregate_failures do
      get "/contact?errors[body][]=blank"

      expect(page).to have_css("form")
      expect(page).to have_no_css(".f-e")
      expect(page).to have_no_css("[aria-invalid]")
    end

    it "fills in nothing the sender never typed" do
      get "/contact?values[subject]=x"

      expect(page.find_by_id("cf-subject")[:value]).to be_nil
    end

    it "answers with the page when the values are not a hash" do
      get "/contact?values=x"

      expect(last_response).to be_ok
    end

    it "answers with the page when the errors are not a hash" do
      get "/contact?errors=x"

      expect(last_response).to be_ok
    end
  end

  describe "a complete submission" do
    before { send_message }

    it "answers with a redirect rather than the confirmation itself", :aggregate_failures do
      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to eq(sent_path)
    end

    it "stores the message" do
      expect(stored.first).to have_attributes(**fields, status: "unread")
    end

    it "stores the sender's daily hash rather than an address" do
      expect(stored.first.visitor_hash).to match(/\A[0-9a-f]{64}\z/)
    end

    it "keys that hash on the salted day and the address alone", :aggregate_failures do
      address = "127.0.0.1"

      expect(stored.first.visitor_hash).to eq(Analytics::Slice["operations.hash_visitor"].call(address:))
      expect(stored.first.visitor_hash).not_to eq(Digest::SHA256.hexdigest(address))
    end

    it "confirms it on the page that follows" do
      follow_redirect!

      expect(page).to have_css(".f-ok strong", exact_text: copy("sent.heading"))
    end

    it "does not read the message back" do
      follow_redirect!

      expect(last_response.body).not_to include(fields[:body])
    end

    it "stores nothing further when that page is asked for again" do
      2.times { get(sent_path) }

      expect(message_queries.messages.count).to eq(1)
    end
  end

  describe "the page reached from another site" do
    it "answers with the page" do
      get "/contact", {}, "HTTP_SEC_FETCH_SITE" => "cross-site"

      expect(last_response).to be_ok
    end
  end

  describe "a submission another site's page sent" do
    it "refuses one the browser marks cross-site", :aggregate_failures do
      send_from("HTTP_SEC_FETCH_SITE" => "cross-site")

      expect(last_response.status).to eq(403)
      expect(message_queries.messages.count).to eq(0)
    end

    it "refuses one from a browser that names only another origin", :aggregate_failures do
      send_from("HTTP_ORIGIN" => "https://evil.example")

      expect(last_response.status).to eq(403)
      expect(message_queries.messages.count).to eq(0)
    end
  end

  describe "a submission the site's own page sent" do
    it "stores one the browser marks same-origin", :aggregate_failures do
      send_from("HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "https://aaronmallen.me")

      expect(last_response.status).to eq(302)
      expect(message_queries.messages.count).to eq(1)
    end

    it "stores one from a client that sends neither header", :aggregate_failures do
      send_from({})

      expect(last_response.status).to eq(302)
      expect(message_queries.messages.count).to eq(1)
    end
  end

  describe "a submission from a client that asks for something other than HTML" do
    %w[application/json text/plain].each do |accept|
      it "goes through for Accept: #{accept}", :aggregate_failures do
        send_from("HTTP_ACCEPT" => accept)

        expect(last_response.status).to eq(302)
        expect(message_queries.messages.count).to eq(1)
      end
    end

    it "comes back unprocessable with the page when a field fails", :aggregate_failures do
      post "/contact", { message: stamped(fields.merge(subject: "")) }, "HTTP_ACCEPT" => "application/json"

      expect(last_response.status).to eq(422)
      expect(last_response.content_type).to eq("text/html; charset=utf-8")
    end
  end

  describe "the honeypot filled" do
    before { send_message(reference: "http://spam.example") }

    it "stores nothing" do
      expect(message_queries.messages.count).to eq(0)
    end

    it "follows the redirect a real sender follows", :aggregate_failures do
      expect(last_response.status).to eq(302)
      expect(last_response.headers["location"]).to eq(sent_path)
    end

    it "gives away no reason it was refused" do
      follow_redirect!

      expect(page).to have_no_css(".f-e")
    end
  end

  describe "the stamp" do
    def caught(**message)
      post("/contact", message:)

      [last_response.status, last_response.headers["location"], message_queries.messages.count]
    end

    def minimum = Hanami.app["settings"].contact[:minimum_submit_seconds]

    def redated(stamp) = stamp.sub(/\A\d+/) { (it.to_i - 60_000).to_s }

    def rendered_stamp = page.find("input[name='message[stamp]']", visible: :all)

    def signed_since_render?(stamp) = Public::Slice["operations.check_contact_stamp"].call(stamp, Time.now + minimum)

    it "rides the form as a hidden field" do
      get "/contact"

      expect(rendered_stamp[:type]).to eq("hidden")
    end

    it "is signed for the moment the page was drawn" do
      get "/contact"

      expect(signed_since_render?(rendered_stamp.value)).to be(true)
    end

    it "lets a send through at the minimum time", :aggregate_failures do
      send_message(stamp: contact_stamp(age: minimum))

      expect(last_response.status).to eq(302)
      expect(stored.first).to have_attributes(**fields)
    end

    it "lets a send through just inside the expiry" do
      send_message(stamp: contact_stamp(age: (24 * 60 * 60) - 60))

      expect(stored.first).to have_attributes(**fields)
    end

    it "sets no cookie on a send it takes or one it drops", :aggregate_failures do
      send_message
      expect(last_response.headers["set-cookie"]).to be_nil

      send_message(stamp: contact_stamp(age: 0))
      expect(last_response.headers["set-cookie"]).to be_nil
    end

    {
      "sent sooner than the minimum time" => -> { stamped(fields, age: 1) },
      "sent before it was drawn" => -> { stamped(fields, age: -60) },
      "with no stamp" => -> { fields },
      "with an empty stamp" => -> { fields.merge(stamp: "") },
      "with a stamp that is not one" => -> { fields.merge(stamp: "soon") },
      "with a stamp whose time was changed" => -> { fields.merge(stamp: redated(contact_stamp)) },
      "with a stamp signed by another key" => -> { fields.merge(stamp: "#{contact_stamp[/\A\d+/]}--#{'0' * 64}") },
      "with a stamp past the expiry" => -> { stamped(fields, age: (24 * 60 * 60) + 1) },
    }.each do |named, message|
      it "stores nothing #{named}, and reads as sent" do
        expect(caught(**instance_exec(&message))).to eq([302, sent_path, 0])
      end
    end

    it "drops a send faster than a minimum set in the settings" do
      change_contact_setting(:minimum_submit_seconds, to: 30)

      expect(caught(**stamped(fields, age: 10))).to eq([302, sent_path, 0])
    end

    it "drops a send older than an expiry set in the settings" do
      change_contact_setting(:stamp_expiry_hours, to: 1)

      expect(caught(**stamped(fields, age: 2 * 60 * 60))).to eq([302, sent_path, 0])
    end

    it "takes a send at once when the settings turn the wait off" do
      change_contact_setting(:minimum_submit_seconds, to: 0)

      expect(caught(**stamped(fields, age: 0))).to eq([302, sent_path, 1])
    end

    describe "on a form sent back with an error" do
      let(:sent) { contact_stamp }

      before { send_message(subject: " ", stamp: sent) }

      it "is drawn new rather than handed back", :aggregate_failures do
        expect(last_response.status).to eq(422)
        expect(rendered_stamp.value).not_to eq(sent)
      end

      it "is signed for the moment the form came back" do
        expect(signed_since_render?(rendered_stamp.value)).to be(true)
      end
    end
  end

  describe "a submission past the limit" do
    let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }

    before do
      limit.times { send_message }
      send_message
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "stores nothing more" do
      expect(message_queries.messages.count).to eq(limit)
    end

    it "comes back with the contact page" do
      expect(page).to have_css(".hd h1", exact_text: copy("heading"))
    end

    it "says the sender has sent enough for now", :aggregate_failures do
      expect(page).to have_css(".f-ok.f-wait strong", exact_text: copy("throttled.heading"))
      expect(page).to have_css(".f-ok.f-wait p", exact_text: copy("throttled.body"))
    end

    it "reads as a wait rather than a send that went through" do
      expect(page).to have_css(".f-ok > i.fa-hourglass-half[aria-hidden='true']")
    end

    it "never says what the limit or the window is" do
      expect(page.find(".f-ok").text).not_to match(/\d/)
    end

    it "offers no form to send again" do
      expect(page).to have_no_css("form")
    end

    it "reads back nothing the sender typed" do
      expect(last_response.body).not_to include(fields[:body])
    end

    it "ends at the answer, with no other way to write" do
      expect(page).to have_no_css(".post-body")
    end

    it "keeps the head and the info list", :aggregate_failures do
      expect(page).to have_css(".stick .hd h1", exact_text: copy("heading"))
      expect(page).to have_css(".stick dl.ci .ci-r", count: 4)
    end
  end

  describe "a run of submissions forging a forwarded address" do
    let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }

    before do
      (limit + 1).times do |sent|
        forged = { "HTTP_X_FORWARDED_FOR" => "203.0.113.#{sent + 1}", "REMOTE_ADDR" => "127.0.0.1" }
        post "/contact", { message: stamped(fields) }, forged
      end
    end

    it "comes back refused once the limit is reached" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(message_queries.messages.count).to eq(limit)
    end
  end

  describe "a run of submissions from one address with a new browser on each" do
    let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }

    before do
      (limit + 1).times do |sent|
        post "/contact", { message: stamped(fields) }, "HTTP_USER_AGENT" => "Mozilla/5.0 x#{sent}"
      end
    end

    it "comes back refused once the limit is reached" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(message_queries.messages.count).to eq(limit)
    end
  end

  describe "a submission from a second address with the same browser" do
    let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }

    def send_from(address)
      post("/contact", { message: stamped(fields) }, "HTTP_USER_AGENT" => "Mozilla/5.0", "REMOTE_ADDR" => address)
    end

    before do
      limit.times { send_from("203.0.113.7") }
      send_from("198.51.100.4")
    end

    it "goes through, since the first address spent only its own allowance", :aggregate_failures do
      expect(last_response.status).to eq(302)
      expect(message_queries.messages.count).to eq(limit + 1)
    end
  end

  describe "a run of submissions from many addresses past the total limit" do
    let(:limit) { 3 }

    before do
      settings = Hanami.app["settings"]
      allow(settings).to receive(:contact).and_return(settings.contact.merge(total_throttle_limit: limit))
      (limit + 1).times do |sent|
        post("/contact", { message: stamped(fields) }, "REMOTE_ADDR" => "203.0.113.#{sent + 1}")
      end
    end

    it "comes back refused" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the total limit" do
      expect(message_queries.messages.count).to eq(limit)
    end
  end

  describe "a run of submissions from many addresses with no total limit set" do
    before do
      21.times do |sent|
        post("/contact", { message: stamped(fields) }, "REMOTE_ADDR" => "203.0.113.#{sent + 1}")
      end
    end

    it "takes twenty from all senders together and refuses the next", :aggregate_failures do
      expect(last_response.status).to eq(429)
      expect(message_queries.messages.count).to eq(20)
    end
  end

  describe "a run of submissions from one IPv6 /64 with a new address on each" do
    let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }

    before do
      (limit + 1).times do |sent|
        post("/contact", { message: stamped(fields) }, "REMOTE_ADDR" => "2001:db8:1:2::#{sent + 1}")
      end
    end

    it "comes back refused once the limit is reached" do
      expect(last_response.status).to eq(429)
    end

    it "stores no more than the limit" do
      expect(message_queries.messages.count).to eq(limit)
    end

    it "keys the hash on the network rather than the address" do
      network = Analytics::Slice["operations.hash_visitor"].call(address: "2001:db8:1:2::")

      expect(stored.first.visitor_hash).to eq(network)
    end
  end

  describe "a submission from a second IPv6 /64" do
    let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }

    before do
      limit.times { post("/contact", { message: stamped(fields) }, "REMOTE_ADDR" => "2001:db8:1:2::1") }
      post("/contact", { message: stamped(fields) }, "REMOTE_ADDR" => "2001:db8:1:3::1")
    end

    it "goes through, since the first network spent only its own allowance" do
      expect(last_response.status).to eq(302)
    end
  end

  describe "a submission from an IPv4 address written as IPv6" do
    let(:limit) { Hanami.app["settings"].contact[:throttle_limit] }

    before do
      limit.times { post("/contact", { message: stamped(fields) }, "REMOTE_ADDR" => "203.0.113.7") }
      post("/contact", { message: stamped(fields) }, "REMOTE_ADDR" => "::ffff:203.0.113.7")
    end

    it "shares the IPv4 address's allowance" do
      expect(last_response.status).to eq(429)
    end
  end

  describe "a submission missing the subject" do
    before { send_message(subject: " ") }

    it "comes back unprocessable" do
      expect(last_response.status).to eq(422)
    end

    it "stores nothing" do
      expect(message_queries.messages.count).to eq(0)
    end

    it "comes back with the page" do
      expect(page).to have_css("form")
    end

    it "names the failing field" do
      expect(page).to have_css("#cf-subject-error.f-e", exact_text: error("subject.blank"))
    end

    it "points the message at the control it is about" do
      expect(page).to have_css("p.f-e[data-for='cf-subject']")
    end

    it "keeps the field to one message, the server's" do
      expect(page.all("p.f-e[data-for='cf-subject']", visible: :all).size).to eq(1)
    end

    it "leaves the browser its copy in the slot the server filled" do
      expect(page.find_by_id("cf-subject-error")[:"data-blank"]).to eq(error("subject.blank"))
    end

    it "marks the failing control invalid", :aggregate_failures do
      expect(page).to have_css("#cf-subject[aria-invalid='true']")
      expect(page).to have_css("#cf-subject[aria-describedby='cf-subject-error']")
    end

    it "leaves the fields that were filled alone", :aggregate_failures do
      expect(page).to have_no_css("#cf-email[aria-invalid]")
      expect(page).to have_no_css("#cf-message[aria-invalid]")
    end

    it "keeps the entries the sender already made", :aggregate_failures do
      expect(page.find_by_id("cf-email")[:value]).to eq(fields[:reply_to])
      expect(page.find_by_id("cf-message").value).to eq(fields[:body])
    end
  end

  describe "a submission holding only Unicode spaces in a field" do
    {
      "the reply address" => [:reply_to, "\u2003", "cf-email", "format"],
      "the subject" => [:subject, "\u2003", "cf-subject", "blank"],
      "the message" => [:body, "\u2003\n\u3000", "cf-message", "blank"],
    }.each do |name, (field, value, id, code)|
      it "comes back unprocessable for #{name}, naming it", :aggregate_failures do
        send_message(field => value)

        expect(last_response.status).to eq(422)
        expect(page).to have_css("##{id}-error.f-e", exact_text: error("#{field}.#{code}"))
      end

      it "stores nothing for #{name}" do
        send_message(field => value)

        expect(message_queries.messages.count).to eq(0)
      end
    end
  end

  describe "a submission carrying an address with a Unicode space inside" do
    before { send_message(reply_to: "ada\u2003lovelace@example.com") }

    it "comes back unprocessable" do
      expect(last_response.status).to eq(422)
    end

    it "names the address" do
      expect(page).to have_css("#cf-email-error.f-e", exact_text: error("reply_to.format"))
    end
  end

  describe "a submission with Unicode spaces around its words" do
    before { send_message(subject: "\u2003A question\u2003", body: "\u00a0About the beacon") }

    it "stores the message as typed", :aggregate_failures do
      expect(last_response.status).to eq(302)
      expect(stored.first).to have_attributes(subject: "\u2003A question\u2003", body: "\u00a0About the beacon")
    end
  end

  describe "a submission longer than the field says it takes" do
    before { send_message(body: "a" * (Contact::Types::MAX_BODY + 1)) }

    it "comes back unprocessable" do
      expect(last_response.status).to eq(422)
    end

    it "stores nothing" do
      expect(message_queries.messages.count).to eq(0)
    end

    it "names the failing field" do
      expect(page).to have_css("#cf-message-error.f-e", exact_text: error("body.long"))
    end

    it "keeps the count line between the message and the error it now carries" do
      expect(page).to have_css("#cf-message + p.f-h + p.f-e", visible: :all)
    end
  end

  describe "a submission carrying an address that is not one" do
    before { send_message(reply_to: "ada") }

    it "comes back unprocessable" do
      expect(last_response.status).to eq(422)
    end

    it "names the address" do
      expect(page).to have_css("#cf-email-error.f-e", exact_text: error("reply_to.format"))
    end

    it "keeps what was typed in it" do
      expect(page.find_by_id("cf-email")[:value]).to eq("ada")
    end
  end

  describe "a submission carrying a control character" do
    def send_control = send_message(body: "hello\u0000world")

    it "comes back unprocessable rather than letting the driver raise" do
      send_control

      expect(last_response.status).to eq(422)
    end

    it "stores nothing" do
      send_control

      expect(message_queries.messages.count).to eq(0)
    end

    {
      "the reply address" => [:reply_to, "ada\u0001@example.com", "cf-email"],
      "the subject" => [:subject, "A\u0001question", "cf-subject"],
      "the message" => [:body, "About\u0001the beacon", "cf-message"],
    }.each do |name, (field, value, id)|
      it "says #{name} holds a hidden character, not to check the field", :aggregate_failures do
        send_message(field => value)

        expect(page).to have_css("##{id}-error.f-e", exact_text: error("#{field}.control"))
        expect(page).to have_no_css(".f-e", exact_text: error("invalid"))
      end
    end

    it "keeps a body holding a tab and a line break" do
      send_message(body: "first\n\tsecond")

      expect(stored.first.body).to eq("first\n\tsecond")
    end
  end

  describe "a submission with nothing in it but its stamp" do
    before { post("/contact", message: stamped({})) }

    it "comes back unprocessable" do
      expect(last_response.status).to eq(422)
    end

    it "names every field" do
      expect(page.all(".f-e").map(&:text))
        .to eq([error("reply_to.blank"), error("subject.blank"), error("body.blank")])
    end
  end

  describe "a body holding HTML" do
    let(:markup) { "<script>alert('x')</script> and <b>bold</b>" }

    it "stores it exactly as the sender typed it" do
      send_message(body: markup)

      expect(stored.first.body).to eq(markup)
    end

    it "reads it back into the field as the text it is" do
      send_message(body: markup, subject: " ")

      expect(page.find_by_id("cf-message").value).to eq(markup)
    end

    it "escapes it rather than serving it as markup", :aggregate_failures do
      send_message(body: markup, subject: " ")

      expect(last_response.body).to include("&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;")
      expect(last_response.body).to include("&lt;b&gt;bold&lt;/b&gt;")
      expect(last_response.body).not_to include("<script>alert")
      expect(last_response.body).not_to include("<b>bold</b>")
    end
  end
end
