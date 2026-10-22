# frozen_string_literal: true

RSpec.describe Contacts::Operations::SavePerson do
  let(:save_person) { Contacts::Slice["operations.save_person"] }
  let(:person_queries) { Contacts::Slice["repos.person_queries"] }
  let(:person_mutations) { Contacts::Slice["repos.person_mutations"] }

  def refusal(id: nil, **params) = save_person.call(params, id:).failure

  def saved(id: nil, **params) = save_person.call(params, id:).value!

  it "saves a contact with a company and no name, handle or key" do
    expect(saved(company: "Analytical Engines")).to have_attributes(name: nil, company: "Analytical Engines", key: nil)
  end

  it "saves a contact with a name and no handle or key" do
    expect(saved(name: "Ada Lovelace")).to have_attributes(key: nil, mastodon_handle: nil, bluesky_handle: nil)
  end

  it "refuses a contact with neither a name nor a company" do
    expect(refusal(given_name: "Ada", nickname: "Countess")).to eq([:invalid, { name: ["blank"] }])
  end

  it "refuses an edit that clears the last of a name and a company" do
    person = saved(name: "Ada Lovelace")

    expect(refusal(name: " ", id: person.id)).to eq([:invalid, { name: ["blank"] }])
  end

  it "keeps a contact's company when an edit clears its name" do
    person = saved(name: "Ada Lovelace", company: "Analytical Engines")

    expect(saved(name: nil, id: person.id)).to have_attributes(name: nil, company: "Analytical Engines")
  end

  it "refuses a handle with no key" do
    expect(refusal(name: "Ada", mastodon_handle: "@ada@ruby.social")).to eq([:invalid, { key: ["blank"] }])
  end

  it "refuses an edit that adds a handle to a contact with no key" do
    person = saved(name: "Ada")

    expect(refusal(mastodon_handle: "@ada@ruby.social", id: person.id)).to eq([:invalid, { key: ["blank"] }])
  end

  it "keeps a key lowercase and refuses one already held", :aggregate_failures do
    expect(saved(name: "Ada", key: " ADA ", mastodon_handle: "@ada@ruby.social").key).to eq("ada")
    expect(refusal(name: "Ada L", key: "Ada", mastodon_handle: "@adal@ruby.social"))
      .to eq([:invalid, { key: ["taken"] }])
  end

  describe "every contact field" do
    let(:texts) do
      {
        name: "Ada Lovelace", name_prefix: "Countess", given_name: "Ada", middle_name: "Augusta", family_name: "King",
        name_suffix: "FRS", phonetic_given_name: "AY-duh", phonetic_middle_name: "aw-GUS-tuh",
        phonetic_family_name: "KING", nickname: "Ada", file_as: "Lovelace, Ada", company: "Analytical Engines",
        job_title: "Analyst", department: "Notes", notes: "the first program\nfor the engine", birthday: "--12-10",
      }
    end
    let(:lists) do
      {
        emails: [{ value: "ada@example.com", type: "home" }], phones: [{ value: "+44 20 7946 0000", type: "mobile" }],
        addresses: [{ street: "12 St James's Square", city: "London", country: "UK", type: "home" }],
        websites: [{ value: "https://example.com/ada", type: "blog" }], chats: [{ value: "ada", type: "Jabber" }],
        dates: [{ value: "1835-07-08", type: "anniversary" }], relations: [{ value: "William King", type: "spouse" }],
        custom_fields: [{ key: "Engine", value: "Analytical" }],
      }
    end

    def stored(**fields) = person_queries.by_id(saved(**fields).id).to_h

    it "keeps the name, work, notes and birthday" do
      expect(stored(**texts)).to include(texts)
    end

    it "keeps each typed list" do
      read_back = lists.transform_values { |rows| rows.map { it.transform_keys(&:to_s) } }

      expect(stored(name: "Ada", **lists)).to include(read_back)
    end

    it "keeps labels trimmed and once each, and the star" do
      expect(stored(name: "Ada", labels: [" family ", "friends", "family"], starred: "1"))
        .to include(labels: %w[family friends], starred: true)
    end

    it "trims an email" do
      expect(stored(name: "Ada", emails: [{ value: " ada@example.com " }]))
        .to include(emails: [{ "value" => "ada@example.com" }])
    end
  end

  it "keeps the fields an edit leaves out" do
    person = saved(name: "Ada", phones: [{ value: "+44 20 7946 0000" }], starred: true)

    expect(saved(nickname: "Countess", id: person.id))
      .to have_attributes(name: "Ada", phones: [{ "value" => "+44 20 7946 0000" }], starred: true)
  end

  it "refuses an email that is not an address" do
    expect(refusal(name: "Ada", emails: [{ value: "ada at example" }]))
      .to eq([:invalid, { emails: { 0 => { value: ["format"] } } }])
  end

  ["1815-13-10", "12/10/1815", "--7-8"].each do |birthday|
    it "refuses the birthday #{birthday.inspect}" do
      expect(refusal(name: "Ada", birthday:)).to eq([:invalid, { birthday: ["format"] }])
    end
  end

  describe "with a Google account that saves new contacts" do
    let!(:connection) { connect_contacts }

    def api = Contacts::Helpers::GooglePerson::API

    def creates(contact, **body)
      stub_request(:post, %r{\A#{api}/people:createContact\?})
        .with(headers: { "Authorization" => "Bearer ya29.me" }, body: hash_including(body))
        .to_return(google_health_json(contact))
    end

    def member(group) = { "contactGroupMembership" => { "contactGroupResourceName" => group } }

    def sent_lists
      {
        "emailAddresses" => [{ "value" => "ada@example.com", "type" => "home" }],
        "addresses" => [{ "city" => "London" }], "birthdays" => [{ "date" => { "month" => 12, "day" => 10 } }],
      }
    end

    before do
      stub_contact_groups({ resourceName: "contactGroups/abc", name: "family", groupType: "USER_CONTACT_GROUP" })
    end

    it "creates the contact in Google under that account and links it", :aggregate_failures do
      create = creates(google_contact("c1", "Ada Lovelace"), "names" => [{ "unstructuredName" => "Ada Lovelace" }])

      expect(saved(name: "Ada Lovelace"))
        .to have_attributes(google_connection_id: connection.id, google_id: "c1", google_etag: "e1")
      expect(create).to have_been_made
    end

    def updates(contact, fields, **body)
      stub_request(:patch, %r{\A#{api}/people/c1:updateContact\?})
        .with(query: hash_including("updatePersonFields" => fields), body: hash_including(body))
        .to_return(google_health_json(contact))
    end

    it "sends the lists and dates Google keeps" do
      create = creates(google_contact("c1", "Ada"), **sent_lists)
      lists = { emails: [{ value: "ada@example.com", type: "home" }], addresses: [{ city: "London" }] }
      saved(name: "Ada", birthday: "--12-10", **lists)

      expect(create).to have_been_made
    end

    it "sends the handles as profile links and keeps them out of websites", :aggregate_failures do
      link = { "value" => "https://ruby.social/@ada", "type" => "Mastodon" }
      create = creates(google_contact("c1", "Ada", urls: [link]), "urls" => [link])

      expect(saved(name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social"))
        .to have_attributes(websites: [], mastodon_handle: "@ada@ruby.social")
      expect(create).to have_been_made
    end

    it "creates an unmatched local person in Google when it is next edited" do
      person = person_mutations.create(name: "Ada")
      create = creates(google_contact("c1", "Ada"), "nicknames" => [{ "value" => "Countess" }])
      saved(nickname: "Countess", id: person.id)

      expect(create).to have_been_made
    end

    it "saves nothing when Google refuses the new contact", :aggregate_failures do
      stub_request(:post, %r{\A#{api}/people:createContact}).to_return(status: 500)

      expect(refusal(name: "Ada")).to eq([:google_failed, "Google answered 500"])
      expect(person_queries.count).to eq(0)
    end

    describe "a contact linked to Google" do
      let(:person) do
        person_mutations.create(name: "Ada", google_connection_id: connection.id, google_id: "c1", google_etag: "e1")
      end

      def held(contact) = stub_request(:get, %r{\A#{api}/people/c1\?}).to_return(google_health_json(contact))

      before do
        held(google_contact("c1", "Ada"))
        stub_request(:post, "#{api}/contactGroups").to_return(google_health_json({ resourceName: "contactGroups/new" }))
      end

      def memberships = %w[abc new starred myContacts].map { member("contactGroups/#{it}") }

      it "updates it in Google, labels and star included", :aggregate_failures do
        back = google_contact("c1", "Ada", etag: "e2", memberships: memberships.first(3))
        update = updates(back, "memberships", "etag" => "e1", "memberships" => memberships)

        expect(saved(labels: %w[family speaking], starred: true, id: person.id))
          .to have_attributes(labels: %w[family speaking], starred: true, google_etag: "e2")
        expect(update).to have_been_made
      end

      it "sends a new name for Google to split when no name part comes with it" do
        update = updates(google_contact("c1", "Ada King"), "names", "names" => [{ "unstructuredName" => "Ada King" }])
        person_mutations.update(person.id, given_name: "Ada")
        saved(name: "Ada King", id: person.id)

        expect(update).to have_been_made
      end

      it "loads Google's version and refuses a save when Google changed it first", :aggregate_failures do
        held(google_contact("c1", "Ada King", etag: "e2"))

        expect(refusal(name: "Ada Lovelace", id: person.id)).to eq(:conflict)
        expect(person_queries.by_id(person.id)).to have_attributes(name: "Ada King", google_etag: "e2")
        expect(a_request(:patch, /updateContact/)).not_to have_been_made
      end

      it "keeps an edit to the key alone off Google" do
        saved(key: "ada", id: person.id)

        expect(a_request(:any, /people/)).not_to have_been_made
      end

      it "keeps the edit off the site when Google refuses it" do
        stub_request(:patch, /updateContact/).to_return(status: 500)
        save_person.call({ name: "Ada King" }, id: person.id)

        expect(person_queries.by_id(person.id).name).to eq("Ada")
      end
    end
  end

  it "holds the database to a name or a company" do
    expect { person_mutations.create(given_name: "Ada") }.to raise_error(ROM::SQL::CheckConstraintError)
  end

  it "holds the database to a key for a contact with a handle" do
    expect { person_mutations.create(name: "Ada", bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada") }
      .to raise_error(ROM::SQL::CheckConstraintError)
  end
end
