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

  it "holds the database to a name or a company" do
    expect { person_mutations.create(given_name: "Ada") }.to raise_error(ROM::SQL::CheckConstraintError)
  end

  it "holds the database to a key for a contact with a handle" do
    expect { person_mutations.create(name: "Ada", bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada") }
      .to raise_error(ROM::SQL::CheckConstraintError)
  end
end
