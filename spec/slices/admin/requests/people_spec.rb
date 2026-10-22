# frozen_string_literal: true

RSpec.describe "Admin people", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:person_queries) { Contacts::Slice["repos.person_queries"] }

  def add(**fields) = admin_post("/admin/contacts", person: fields)

  def error(field, code) = i18n.t(["ui.components.people.field_error", field, code].join("."))

  def everyone = person_queries.all

  def names = page.all(".contact-row-name").map(&:text)

  def resolves(handle, did)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(did:))
  end

  def synced(at)
    Contacts::Slice["repos.person_mutations"].store_google(connect_google.id, { people: [], sync_token: "t" }, now: at)
  end

  def synced_text(at) = i18n.t("ui.views.people.index.synced", at: i18n.l(Blog::TimeZone.local(at), format: :short))

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the tab" do
      it "sits in the Inbox group after webmentions" do
        get "/admin/contacts"

        expect(page.all("nav.screen-tabs-list a.screen-tab").map { it[:href] }.last(2))
          .to eq(%w[/admin/webmentions /admin/contacts])
      end

      it "counts the contacts on its tab" do
        2.times { create(:person) }
        get "/admin/contacts"

        expect(page.find("a.screen-tab[aria-current='page']")).to have_text("contacts")
          .and have_css(".screen-tab-note", text: "2")
      end

      it "opens from the command palette's inbox rows" do
        get "/admin"

        expect(page).to have_css("#command-palette-contacts[data-palette-href='/admin/contacts']", visible: :all)
      end

      it "leaves People off the webmentions settings tab", :aggregate_failures do
        create(:person)
        get "/admin/settings/webmentions"

        expect(page.all(".settings-section").map { it[:id] }).to eq(%w[webmentions])
        expect(page).to have_no_css(".contact-row, .person-row")
      end

      it "sends the old People addresses to Contacts", :aggregate_failures do
        get "/admin/people"
        expect([last_response.status, last_response.location]).to eq([302, "/admin/contacts"])

        get "/admin/people/new"
        expect(last_response.location).to eq("/admin/contacts/new")
      end
    end

    describe "the list" do
      it "says who to add when there is nobody yet" do
        get "/admin/contacts"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.people.index.empty"))
      end

      it "counts everyone and offers a new contact and a sync", :aggregate_failures do
        2.times { create(:person) }
        get "/admin/contacts"

        expect(page.find(".page-head-sub")).to have_text("2 contacts, synced both ways with Google Contacts")
        expect(page).to have_link("New contact", href: "/admin/contacts/new")
        expect(page).to have_css("form[action='/admin/contacts/sync'] button", text: "Sync now")
      end

      it "says when Google has not synced yet" do
        get "/admin/contacts"

        expect(page.find(".page-head-sub")).to have_text(i18n.t("ui.views.people.index.never_synced"))
      end

      it "shows when the last sync ran" do
        at = Time.utc(2026, 10, 22, 17)
        synced(at)
        get "/admin/contacts"

        expect(page.find(".page-head-sub")).to have_text(synced_text(at))
      end

      it "says when the last sync failed" do
        Record::Slice["repos.sync_state_mutations"].record_failure("contacts", "crashed", message: "boom")
        get "/admin/contacts"

        expect(page.find(".page-head-sub")).to have_text(i18n.t("ui.views.people.index.sync_failed"))
      end

      it "lists everyone by file-as name, then name, then company" do
        create(:person, name: "Grace Hopper")
        create(:person, name: "Ada Lovelace", file_as: "Lovelace, Ada")
        create(:person, name: nil, key: nil, mastodon_handle: nil, company: "Babbage & Co")

        expect(get("/admin/contacts") && names).to eq(["Babbage & Co", "Grace Hopper", "Ada Lovelace"])
      end

      describe "a row" do
        let(:row) { page.find(".contact-row") }

        before do
          create(:person, name: "Ada Lovelace", given_name: "Ada", family_name: "Lovelace", starred: true,
                          job_title: "Analyst", company: "Engines",
                          emails: [{ value: "ada@example.com" }, { value: "ada@work.example" }])
          get "/admin/contacts"
        end

        it "draws initials, a star, the title and company", :aggregate_failures do
          expect(row.find(".contact-row-avatar").text).to eq("AL")
          expect(row).to have_css("i.fa-star[aria-label='Starred']")
          expect(row.find(".contact-row-sub").text).to eq("Analyst · Engines")
        end

        it "draws the first email with a count of the rest" do
          expect(row.find("a.contact-row-email[href='mailto:ada@example.com']").all("span").map(&:text))
            .to eq(["ada@example.com", "+1"])
        end
      end

      it "says when someone has no email" do
        create(:person)
        get "/admin/contacts"

        expect(page.find(".contact-row-none").text.strip).to eq("no email")
      end

      it "takes the first two letters of a name with no parts" do
        create(:person, name: "ada")

        expect(get("/admin/contacts") && page.find(".contact-row-avatar").text).to eq("AD")
      end

      it "links each handle and shows each label", :aggregate_failures do
        create(:person, mastodon_handle: "@ada@ruby.social", labels: %w[family speaking])
        get "/admin/contacts"

        expect(page).to have_link(class: "person-link", href: "https://ruby.social/@ada")
        expect(page.all(".contact-row-meta .tag").map(&:text)).to eq(%w[#family #speaking])
      end

      it "opens each contact's page from the name, edits from the pencil and offers a menu", :aggregate_failures do
        person = create(:person, name: "Ada")
        get "/admin/contacts"

        expect(page).to have_css("a.contact-row-name[href='/admin/contacts/#{person.id}'][data-key-open]")
        expect(page).to have_css(".contact-row .hov a[href='/admin/contacts/#{person.id}/edit'][title='Edit Ada']")
        expect(page).to have_css(".contact-row[data-menu='/admin/contacts/#{person.id}/menu']")
      end
    end

    describe "searching and filtering the list" do
      before do
        create(:person, name: "Ada Lovelace", nickname: "Countess", key: "ada", company: "Engines",
                        job_title: "Analyst", mastodon_handle: "@ada@ruby.social",
                        emails: [{ value: "ada@example.com" }],
                        phones: [{ value: "+44 20 7946 0000" }], labels: %w[family], starred: true)
        create(:person, name: "Grace Hopper", key: nil, mastodon_handle: nil, labels: %w[navy])
      end

      {
        "name" => "lovelace", "nickname" => "countess", "key" => "ada", "company" => "engines", "title" => "analyst",
        "handle" => "ruby.social", "email" => "ada@example", "phone" => "7946",
      }.each do |field, query|
        it "finds a contact by #{field}" do
          expect(get("/admin/contacts", q: query) && names).to eq(["Ada Lovelace"])
        end
      end

      it "finds nobody by an email type" do
        create(:person, name: "Alan", emails: [{ value: "alan@example.com", type: "work" }])

        expect(get("/admin/contacts", q: "work") && names).to be_empty
      end

      it "says so when nothing matches" do
        get "/admin/contacts", q: "nobody"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.people.index.no_match"))
      end

      it "shows only the starred" do
        expect(get("/admin/contacts", show: "starred") && names).to eq(["Ada Lovelace"])
      end

      it "shows only those a post can mention" do
        expect(get("/admin/contacts", show: "mentionable") && names).to eq(["Ada Lovelace"])
      end

      it "shows everyone for a show it does not know" do
        expect(get("/admin/contacts", show: "bogus") && names).to eq(["Ada Lovelace", "Grace Hopper"])
      end

      it "shows one label" do
        expect(get("/admin/contacts", label: "navy") && names).to eq(["Grace Hopper"])
      end

      it "draws all, starred and mentionable as links that keep the search" do
        get "/admin/contacts", q: "a", label: "family"
        shows = %w[all starred mentionable].map { [it, it == "all" ? "" : "&show=#{it}"] }

        expect(page.all("nav.seg a.seg-option").map { [it.text, it[:href]] })
          .to eq(shows.map { |show, query| [show, "/admin/contacts?q=a#{query}&label=family"] })
      end

      it "marks the show in use" do
        get "/admin/contacts", show: "starred"

        expect(page).to have_css("nav.seg a.current[aria-current='page']", text: "starred")
      end

      it "draws a pill per label that turns its filter on and off", :aggregate_failures do
        get "/admin/contacts", label: "family"

        pills = page.all(".contacts-labels a.search-kind").map { [it.text, it[:href], it["aria-current"]] }
        expect(pills).to eq([["#family", "/admin/contacts", "page"], ["#navy", "/admin/contacts?label=navy", nil]])
      end

      it "keeps the filters in the search form", :aggregate_failures do
        get "/admin/contacts", show: "starred", label: "family"

        form = page.find("form.contacts-search[role='search']")
        expect(form).to have_field("show", with: "starred", type: :hidden)
        expect(form).to have_field("label", with: "family", type: :hidden)
      end
    end

    describe "the contact page" do
      let(:person) do
        fields = {
          name: "Ada Lovelace", given_name: "Ada", family_name: "Lovelace", key: "ada",
          mastodon_handle: "@ada@ruby.social", nickname: "Countess", company: "Engines",
          job_title: "Analyst", department: "Notes", birthday: "1815-12-10",
          emails: [{ value: "ada@example.com", type: "home" }], phones: [{ value: "+44 20 7946 0000", type: "mobile" }],
          addresses: [{ street: "12 St James's Square", city: "London", country: "UK" }],
          websites: [{ value: "https://ada.example" }, { value: "javascript:alert(1)" }],
          chats: [{ value: "ada", type: "Jabber" }], dates: [{ value: "--07-08", type: "anniversary" }],
          relations: [{ value: "William King", type: "spouse" }],
          custom_fields: [{ key: "Engine", value: "Analytical" }], notes: "the first program",
          labels: %w[family], file_as: "Lovelace, Ada",
        }
        create(:person, :bluesky, **fields)
      end

      def age
        today = Blog::TimeZone.local_date(Time.now)
        today.year - 1815 - (today.strftime("%m-%d") < "12-10" ? 1 : 0)
      end

      def parts(label) = row(label).all(".contact-v > *").map(&:text)

      def row(label) = page.find(:xpath, "//dt[normalize-space(.)='#{label}']/following-sibling::dd[1]")

      describe "seen" do
        before { get "/admin/contacts/#{person.id}" }

        it "heads the page with initials, name, work and labels", :aggregate_failures do
          expect(page.find(".contact-avatar").text).to eq("AL")
          expect(page.find("h1.contact-head-title").text).to eq("Ada Lovelace")
          expect(page.find(".contact-head-sub").text).to eq("Analyst · Notes · Engines")
          expect(page.all(".contact-head-labels .tag").map(&:text)).to eq(%w[#family])
        end

        it "leads back to the contacts" do
          expect(page).to have_link("Contacts", href: "/admin/contacts")
        end

        it "offers email, star and edit", :aggregate_failures do
          expect(CGI.unescape(page.find_link("Email")[:href])).to eq("/admin/mail?compose=1&to=ada@example.com")
          expect(page).to have_css("form[action='/admin/contacts/#{person.id}/star'] input[value='1']", visible: :all)
            .and have_button("Star")
          expect(page).to have_link("Edit", href: "/admin/contacts/#{person.id}/edit")
        end

        it "shows the ways to reach them", :aggregate_failures do
          expect(row("Email")).to have_link("ada@example.com", href: "mailto:ada@example.com").and have_text("home")
          expect(row("Phone")).to have_link("+44 20 7946 0000", href: "tel:+442079460000")
          expect(row("Address").find("a.contact-address").text).to eq("12 St James's Square\nLondon\nUK")
          expect(parts("Chat")).to eq(%w[ada Jabber])
        end

        it "shows the handles and the mention to copy", :aggregate_failures do
          expect(row("Mastodon")).to have_link(href: "https://ruby.social/@ada")
          expect(row("Bluesky")).to have_link(href: "https://bsky.app/profile/#{person.bluesky_did}")
          expect(row("Mention as")).to have_text("@{ada}").and have_css("button[data-record-key='@{ada}']")
        end

        it "shows the work and personal fields", :aggregate_failures do
          expect([row("Company"), row("Job title"), row("Department")].map(&:text)).to eq(%w[Engines Analyst Notes])
          expect([row("Nickname").text, *parts("Birthday")]).to eq(["Countess", "Dec 10, 1815", "#{age} years"])
          expect(parts("Dates") + parts("Related")).to eq(["Jul 8", "anniversary", "William King", "spouse"])
        end

        it "shows the custom fields and notes", :aggregate_failures do
          expect(row("Engine").text).to eq("Analytical")
          expect(page.find(".contact-notes").text).to eq("the first program")
        end

        it "links only web addresses as websites", :aggregate_failures do
          expect(row("Website")).to have_link("ada.example", href: "https://ada.example")
          expect(row("Website")).to have_no_link("javascript:alert(1)").and have_text("javascript:alert(1)")
        end
      end

      it "leaves out the sections with nothing in them" do
        get "/admin/contacts/#{create(:person, name: 'Grace', key: nil, mastodon_handle: nil).id}"

        expect(page.all(".contact-card .contact-sec h3").map(&:text)).to be_empty
      end

      def thread(subject, from, ago)
        create(:message, subject:, received_at: Time.now - ago).tap do |thread|
          create(:mail_message, mail_thread_id: thread.id, reply_to: from)
        end
      end

      it "lists the last six mail threads with the contact, newest first, in any case", :aggregate_failures do
        threads = Array.new(7) { |n| thread("Thread #{n}", n.even? ? "ADA@example.com" : "ada@example.com", n * 60) }
        thread("Other", "grace@example.com", 0)
        get "/admin/contacts/#{person.id}"

        expect(page.all(".contact-mail-subject").map(&:text)).to eq((0..5).map { "Thread #{it}" })
        expect(page.first("a.contact-mail")[:href]).to eq("/admin/mail?thread=#{threads.first.id}")
      end

      it "marks an unread thread" do
        thread("Engines", "ada@example.com", 0)
        get "/admin/contacts/#{person.id}"

        expect(page.find(".contact-mail-meta")).to have_text("unread")
      end

      it "says when there is no mail with the contact" do
        get "/admin/contacts/#{person.id}"

        expect(page.find(".contact-mail-empty").text)
          .to eq(i18n.t("ui.components.people.mail_card.empty", who: "ada@example.com"))
      end

      describe "held by Google" do
        let(:card) { page.find(".contact-google") }

        before do
          connection = connect_google(account_id: "aaron@example.com")
          Contacts::Slice["repos.person_mutations"]
            .update(person.id, google_connection_id: connection.id, google_id: "c5502913380")
          get "/admin/contacts/#{person.id}"
        end

        it "draws the account, the sync state and the Google fields", :aggregate_failures do
          expect(card).to have_css(".contact-sync.on", text: "in sync")
          expect(card).to have_text("aaron@example.com").and have_text("people/c5502913380")
          expect(card).to have_text("Lovelace, Ada")
        end

        it "links to the contact in Google" do
          expect(card).to have_link("Open in Google Contacts", href: "https://contacts.google.com/person/c5502913380")
        end
      end

      it "marks a contact Google does not hold yet" do
        get "/admin/contacts/#{person.id}"

        expect(page.find(".contact-google")).to have_css(".contact-sync:not(.on)", text: "here only")
          .and have_no_link("Open in Google Contacts")
      end

      it "stars and unstars the contact", :aggregate_failures do
        admin_post("/admin/contacts/#{person.id}/star", starred: "1")
        expect(person_queries.by_id(person.id).starred).to be(true)
        expect(last_response.location).to eq("/admin/contacts/#{person.id}")

        admin_post("/admin/contacts/#{person.id}/star", starred: "0")
        expect(person_queries.by_id(person.id).starred).to be(false)
      end

      it "answers 404 for a contact who is not there" do
        get "/admin/contacts/999999"

        expect(last_response).to be_not_found
      end
    end

    describe "adding a contact" do
      it "draws every field with no script", :aggregate_failures do
        get "/admin/contacts/new"

        form = page.find("form[method='post'][action='/admin/contacts'][data-contact-form]")
        names = %w[given_name family_name name_prefix nickname company job_title mastodon_handle key birthday notes]
        expect(names.reject { form.has_field?("person[#{it}]", visible: :all) }).to be_empty
        expect(form).to have_button("Add contact")
      end

      it "keeps a blank row of each list to add from" do
        get "/admin/contacts/new"

        expect(last_response.body).to match(
          /<template data-contact-template="">\s*<div class="contact-entry"[^>]*><input[^>]*emails\]\[\]\[value/,
        )
      end

      it "hides the extra name fields until asked" do
        get "/admin/contacts/new"

        expect(page).to have_css("[data-contact-extra][hidden] input[name='person[name_prefix]']", visible: :all)
      end

      it "builds the name from its parts" do
        add(name_prefix: "Dr.", given_name: "Ada", middle_name: "Augusta", family_name: "King", name_suffix: "FRS")

        expect(everyone.first.name).to eq("Dr. Ada Augusta King, FRS")
      end

      it "keeps the filled rows of each list and drops the blank ones", :aggregate_failures do
        add(given_name: "Ada", emails: [{ value: "ada@example.com", type: "home" }, { value: "", type: "work" }],
            addresses: [{ street: "", city: "London", type: "home" }, { street: "", city: "", type: "work" }])

        expect(everyone.first.emails).to eq([{ "value" => "ada@example.com", "type" => "home" }])
        expect(everyone.first.addresses).to eq([{ "city" => "London", "type" => "home" }])
      end

      it "keeps a custom field" do
        add(given_name: "Ada", custom_fields: [{ key: "Engine", value: "Analytical" }])

        expect(everyone.first.custom_fields).to eq([{ "key" => "Engine", "value" => "Analytical" }])
      end

      it "keeps the picked labels, a new one as a key, and the star" do
        add(given_name: "Ada", labels: %w[family], new_label: "Ruby Friends", starred: "1")

        expect(everyone.first).to have_attributes(labels: %w[family ruby-friends], starred: true)
      end

      it "goes to the new contact's page and says so", :aggregate_failures do
        add(given_name: "Ada")
        follow_redirect!

        expect(last_request.path).to eq("/admin/contacts/#{everyone.first.id}")
        expect(page).to have_css("[data-toast]", text: "Contact added")
      end

      it "keeps a mail sender's email when the new contact is refused" do
        add(emails: [{ value: "ada@example.com" }])

        expect(page).to have_field("person[emails][][value]", with: "ada@example.com")
      end

      it "takes a company with no name" do
        add(company: "Analytical Engines")

        expect(everyone.map { [it.name, it.company] }).to eq([[nil, "Analytical Engines"]])
      end

      it "fills a new contact from a name and an email", :aggregate_failures do
        get "/admin/contacts/new", name: "Ada Lovelace", email: "ada@example.com"

        expect(page).to have_field("person[given_name]", with: "Ada")
          .and have_field("person[family_name]", with: "Lovelace")
        expect(page).to have_field("person[emails][][value]", with: "ada@example.com")
      end

      {
        "a blank name and company" => [{ nickname: "Countess" }, :name, :blank],
        "an email that is not an address" => [{ given_name: "Ada", emails: [{ value: "ada at" }] }, :emails, :format],
        "a handle with no key" => [{ given_name: "Ada", mastodon_handle: "@ada@ruby.social" }, :key, :blank],
        "a bad key" => [{ given_name: "Ada", mastodon_handle: "@ada@ruby.social", key: "Ada L" }, :key, :format],
        "a bad Mastodon handle" => [{ given_name: "Ada", key: "ada", mastodon_handle: "ada" }, :mastodon_handle,
                                    :format],
        "a bad Bluesky handle" => [{ given_name: "Ada", key: "ada", bluesky_handle: "ada" }, :bluesky_handle, :format],
      }.each do |what, (fields, field, code)|
        it "refuses #{what} beside the field and keeps what was typed", :aggregate_failures do
          add(**fields)

          expect(last_response.status).to eq(422)
          expect(page).to have_css("#person-#{field}-error", text: error(field, code))
          expect(page).to have_field("person[given_name]", with: fields[:given_name].to_s)
        end
      end

      it "refuses a key someone else holds" do
        create(:person, key: "ada")
        add(given_name: "Ada", key: "ada", mastodon_handle: "@ada2@ruby.social")

        expect(page).to have_css("#person-key-error", text: error(:key, :taken))
      end

      it "stores the DID a Bluesky handle resolves to" do
        resolves("ada.bsky.social", "did:plc:ada")
        add(given_name: "Ada", key: "ada", bluesky_handle: "ada.bsky.social")

        expect(everyone.first).to have_attributes(bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada")
      end
    end

    describe "adding a person from the social composer" do
      def blank = { name: "", key: "", mastodon_handle: "", bluesky_handle: "" }

      def mention(**fields) = admin_post("/admin/contacts", reply: "mention", person: { **blank, **fields })

      it "answers with the new option for the mention list", :aggregate_failures do
        mention(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(last_response.status).to eq(201)
        expect(page).to have_css(
          "[role='option'][data-social-mention='ada'][data-social-mention-in='mastodon']", text: "Ada Lovelace",
        )
      end

      it "answers with the handles each network shows" do
        mention(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")
        named = { "ada" => "Ada Lovelace" }

        expect(JSON.parse(page.find("[data-social-people]", visible: :all)["data-social-people"]))
          .to eq("mastodon" => { "ada" => "@ada@ruby.social" }, "bluesky" => named, "linkedin" => named)
      end

      it "answers with no layout and no toast", :aggregate_failures do
        mention(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(last_response.body).not_to include("<html")
        expect(last_response.headers["Set-Cookie"].to_s).not_to include("Person added")
      end

      it "stores the person" do
        mention(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(everyone.map(&:key)).to eq(%w[ada])
      end

      it "draws the short form for the composer's dialog" do
        get "/admin/contacts/new", reply: "mention"

        expect(page).to have_css("form[data-person-form='new'][action='/admin/contacts'] input[name='person[name]']")
      end

      it "answers a refusal with the form and its errors", :aggregate_failures do
        mention(name: "Ada", mastodon_handle: "@ada@ruby.social")

        expect(last_response.status).to eq(422)
        expect(page).to have_css("form[data-person-form='new'] #person-key-error", text: error(:key, :blank))
      end
    end

    describe "editing a contact" do
      let(:person) do
        create(:person, name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social",
                        phones: [{ value: "+44 20 7946 0000", type: "mobile" }], labels: %w[family])
      end

      def save(**fields) = admin_post("/admin/contacts/#{person.id}", person: fields)

      it "splits a name with no parts into first and last" do
        get "/admin/contacts/#{person.id}/edit"

        expect(page).to have_field("person[given_name]", with: "Ada")
          .and have_field("person[family_name]", with: "Lovelace")
      end

      it "fills the lists, labels and the star", :aggregate_failures do
        get "/admin/contacts/#{person.id}/edit"

        expect(page).to have_field("person[phones][][value]", with: "+44 20 7946 0000")
        expect(page).to have_select("person[phones][][type]", selected: "mobile")
        expect(page).to have_field("person[labels][]", with: "family", checked: true, visible: :all)
        expect(page).to have_field("person[starred]", checked: false)
      end

      it "offers each label any contact holds" do
        create(:person, labels: %w[navy])
        get "/admin/contacts/#{person.id}/edit"

        expect(page.all("input[name='person[labels][]']", visible: :all).map { [it.value, it.checked?] })
          .to eq([["family", true], ["navy", false]])
      end

      it "saves every field it shows, list and label removals included" do
        save(given_name: "Ada", family_name: "King", key: "ada", mastodon_handle: "@ada@ruby.social", company: "IBM")

        expect(person_queries.by_id(person.id))
          .to have_attributes(name: "Ada King", company: "IBM", phones: [], labels: [], starred: false)
      end

      it "says it saved" do
        save(given_name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social")
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Contact saved")
      end

      it "goes back to the contact's page" do
        save(given_name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(last_response.location).to eq("/admin/contacts/#{person.id}")
      end

      it "keeps the edit and shows the error on a refusal", :aggregate_failures do
        save(given_name: "Ada", key: "", mastodon_handle: "@ada@ruby.social", nickname: "Countess")

        expect(page).to have_css("#person-key-error", text: error(:key, :blank))
        expect(page).to have_field("person[nickname]", with: "Countess")
        expect(person_queries.by_id(person.id).key).to eq("ada")
      end

      it "asks before deleting here and in Google" do
        get "/admin/contacts/#{person.id}/edit"

        expect(page).to have_css(
          "form#person-delete[method='post'][action='/admin/contacts/#{person.id}/delete']" \
          "[data-confirm='Delete Ada Lovelace here and in Google?']",
        ).and have_css("button[form='person-delete']", text: "Delete")
      end

      it "deletes and goes back to the list", :aggregate_failures do
        admin_post("/admin/contacts/#{person.id}/delete")
        expect(last_response.location).to eq("/admin/contacts")
        follow_redirect!

        expect(everyone).to be_empty
        expect(page).to have_css("[data-toast]", text: "Contact deleted")
      end

      it "answers 404 for a contact who is not there" do
        get "/admin/contacts/999999/edit"

        expect(last_response).to be_not_found
      end
    end

    describe "searching for accounts" do
      let(:ada) { { avatar: "https://cdn.bsky.app/ada.jpg", displayName: "Ada Lovelace", handle: "ada.bsky.social" } }
      let(:grace) do
        { acct: "grace@hachyderm.io", avatar: "https://files.example/grace.png", display_name: "Grace Hopper" }
      end

      def results
        page.all("[data-person-add]").map { [it["data-person-add"], CGI.unescape(it[:href])[/name=([^&]+)/, 1]] }
      end

      def search(network, query) = get("/admin/contacts/search/#{network}", q: query)

      before { connect_social_networks }

      it "lists Bluesky accounts with avatar, name and handle", :aggregate_failures do
        stub_bluesky_search("ada", ada)
        search("bluesky", "ada")

        expect(results).to eq([["ada.bsky.social", "Ada Lovelace"]])
        expect(page).to have_css("[data-person-result] img[src='https://cdn.bsky.app/ada.jpg'][alt='']")
        expect(page).to have_css("[data-person-result] .person-result-handle.bluesky", text: "@ada.bsky.social")
      end

      it "answers with rows and no layout" do
        stub_bluesky_search("ada", ada)
        search("bluesky", "ada")

        expect(last_response.body).not_to include("<html")
      end

      it "lists Mastodon accounts on other instances as @user@instance" do
        stub_mastodon_search("grace", grace)
        search("mastodon", "grace")

        expect(results).to eq([["@grace@hachyderm.io", "Grace Hopper"]])
      end

      it "names a Mastodon account on the site's own instance with that instance" do
        stub_mastodon_search("ada", { acct: "ada", avatar: "https://ruby.social/ada.png", display_name: "Ada" })
        search("mastodon", "ada")

        expect(results).to eq([["@ada@ruby.social", "Ada"]])
      end

      it "shows the handle where an account has no display name" do
        stub_bluesky_search("ada", ada.merge(displayName: ""))
        search("bluesky", "ada")

        expect(page.find(".person-result-name").text).to eq("ada.bsky.social")
      end

      it "draws no avatar from an address that is not HTTPS" do
        stub_bluesky_search("ada", ada.merge(avatar: "http://cdn.example/ada.jpg"))
        search("bluesky", "ada")

        expect(page).to have_no_css("img")
      end

      it "says so when nothing matches", :aggregate_failures do
        stub_bluesky_search("nobody")
        search("bluesky", "nobody")

        expect(page).to have_css(".empty", text: "No accounts match")
        expect(results).to be_empty
      end

      it "asks no network for a query shorter than two characters", :aggregate_failures do
        search("bluesky", " a ")

        expect(last_response).to be_ok
        expect(a_request(:get, /searchActorsTypeahead/)).not_to have_been_made
      end

      it "shows an error row when the network fails", :aggregate_failures do
        stub_bluesky_search("ada", status: 502)
        search("bluesky", "ada")

        expect(last_response.status).to eq(502)
        expect(page).to have_css("[data-person-finder-note='failed']", text: "Bluesky did not answer")
      end

      it "shows an error row when the network times out" do
        stub_request(:get, SocialNetworks::MASTODON_SEARCH).with(query: hash_including({})).to_timeout
        search("mastodon", "grace")

        expect(page).to have_css("[data-person-finder-note='failed']", text: "Mastodon did not answer")
      end

      it "shows an error row when the network rate limits", :aggregate_failures do
        stub_mastodon_search("grace", status: 429)
        search("mastodon", "grace")

        expect(last_response.status).to eq(429)
        expect(page).to have_css("[data-person-finder-note='rate_limited']", text: "too many searches")
      end

      it "answers 404 for a network with no credentials" do
        connect_social_networks(bluesky: {})
        search("bluesky", "ada")

        expect(last_response).to be_not_found
      end

      it "answers 404 for a network it does not know" do
        search("myspace", "ada")

        expect(last_response).to be_not_found
      end

      it "opens a new contact filled from the account it found" do
        stub_bluesky_search("ada", ada)
        search("bluesky", "ada")

        expect(CGI.unescape(page.find("[data-person-add]")[:href])).to eq(
          "/admin/contacts/new?name=Ada Lovelace&person[key]=ada&person[bluesky_handle]=ada.bsky.social",
        )
      end

      it "counts the accounts it found" do
        stub_bluesky_search("ada", ada, ada.merge(handle: "ada2.bsky.social"))
        search("bluesky", "ada")

        expect(page).to have_css("[data-person-finder-count]", text: "2 accounts found")
      end

      it "offers one search panel beside the people list", :aggregate_failures do
        get "/admin/contacts"

        expect(page).to have_css(".g-main > aside[data-person-finder][hidden]", visible: :all)
        expect(page.all("[data-person-finder] input[name='network']", visible: :all).map(&:value))
          .to eq(%w[mastodon bluesky])
      end

      it "offers only the networks with credentials" do
        connect_social_networks(mastodon: {})
        get "/admin/contacts"

        expect(page.all("[data-person-finder] input[name='network']", visible: :all).map(&:value)).to eq(%w[bluesky])
      end

      it "leaves the panel out when no network has credentials" do
        connect_social_networks(bluesky: {}, mastodon: {})
        get "/admin/contacts"

        expect(page).to have_no_css("[data-person-finder]", visible: :all).and have_no_css(".g-main")
      end

      it "gives the person form no search boxes", :aggregate_failures do
        get "/admin/contacts/new"
        expect(page).to have_no_field(type: "search", visible: :all)

        get "/admin/contacts/#{create(:person).id}/edit"
        expect(page).to have_no_field(type: "search", visible: :all)
      end
    end

    describe "a contact linked to Google" do
      let(:api) { Contacts::Helpers::GooglePerson::API }
      let(:person) do
        linked = { google_connection_id: connect_contacts.id, google_id: "c1", google_etag: "e1" }
        create(:person, name: "Ada", given_name: "Ada", key: "ada", mastodon_handle: nil, **linked)
      end

      def alert = page.find("[role=alert]").text

      def changed_in_google
        names = [{ displayName: "Ada King", givenName: "Ada", familyName: "King" }]
        newer = google_contact("c1", "Ada King", etag: "e2", names:)
        stub_request(:get, %r{\A#{api}/people/c1\?}).to_return(google_health_json(newer))
      end

      def save = admin_post("/admin/contacts/#{person.id}", person: { given_name: "Ada", nickname: "Countess" })

      before { stub_contact_groups }

      it "loads Google's version on the editor when Google changed it first", :aggregate_failures do
        changed_in_google
        save

        expect(page).to have_field("person[family_name]", with: "King").and have_field("person[nickname]", with: "")
        expect(alert).to eq(i18n.t("people_page.toasts.conflict"))
      end

      it "keeps the typed edit on the editor when Google refuses it", :aggregate_failures do
        stub_request(:get, %r{\A#{api}/people/c1\?}).to_return(google_health_json(google_contact("c1", "Ada")))
        stub_request(:patch, /updateContact/).to_return(status: 500)
        save

        expect(page).to have_field("person[nickname]", with: "Countess")
        expect(alert).to eq(i18n.t("people_page.toasts.google_failed"))
      end

      it "keeps the contact and says so when Google refuses the delete", :aggregate_failures do
        stub_request(:delete, "#{api}/people/c1:deleteContact").to_return(status: 500)
        admin_post("/admin/contacts/#{person.id}/delete")
        follow_redirect!

        expect(everyone.map(&:id)).to eq([person.id])
        expect(page).to have_css("[data-toast]", text: i18n.t("people_page.toasts.google_failed"))
      end
    end
  end
end
