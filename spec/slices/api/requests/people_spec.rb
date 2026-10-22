# frozen_string_literal: true

RSpec.describe "API people", type: :request do
  let(:person_queries) { Contacts::Slice["repos.person_queries"] }
  let(:open) { api_token(Blog::Types::OAuthScope.values - %w[contacts]) }

  def add(token: api_token, **fields) = call_api(:post, "/people", JSON.generate(fields), token:)

  def edit(id, token: api_token, **fields) = call_api(:patch, "/people/#{id}", JSON.generate(fields), token:)

  def everyone = person_queries.all

  def insufficient
    [status, last_response.headers["WWW-Authenticate"]]
  end

  def json_of(person)
    stamps = person.to_h.slice(:created_at, :updated_at).transform_values { it.utc.iso8601 }
    fields = API::Serializers::Person::SCHEMA.fetch(:properties).keys - %i[created_at updated_at]

    person.to_h.slice(*fields).merge(stamps, labels: person.labels.to_a).transform_keys(&:to_s)
  end

  def list(token: api_token, **params) = call_api(:get, "/people", params, token:)

  def private_fields
    {
      company: "Analytical Engines", emails: [{ "value" => "ada@example.com", "type" => "work" }],
      addresses: [{ "city" => "London" }], custom_fields: [{ "key" => "Engine", "value" => "Difference" }],
      birthday: "1815-12-10", labels: %w[Family], starred: true,
    }
  end

  def read(id, token: api_token) = call_api(:get, "/people/#{id}", nil, token:)

  def remove(id, token: api_token) = call_api(:delete, "/people/#{id}", nil, token:)

  def resolves(handle, did)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(did:))
  end

  def search(network, text) = call_api(:get, "/people/search/#{network}", { query: text })

  def sync(token: api_token) = call_api(:post, "/people/sync", "{}", token:)

  def unknown(handle)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(status: 400, error: "InvalidRequest", message: "Unable to resolve handle"))
  end

  def unscoped = [403, %(Bearer error="insufficient_scope", scope="contacts")]

  describe "GET /api/v1/people" do
    it "lists everyone by name" do
      create(:person, name: "Grace Hopper")
      create(:person, name: "Ada Lovelace")

      expect(list.fetch("people").map { it.fetch("name") }).to eq(["Ada Lovelace", "Grace Hopper"])
    end

    it "gives each person every field" do
      ada = create(:person, :bluesky, mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social",
                                      company: "Analytical Engines", emails: [{ value: "ada@example.com" }])

      expect(list.fetch("people")).to eq([json_of(ada)])
    end

    it "gives a token without contacts only the ID, name, key and handles" do
      ada = create(:person, company: "Analytical Engines", notes: "Met at the salon")

      expect(list(token: open).fetch("people"))
        .to eq([ada.to_h.slice(:id, :key, :name, :mastodon_handle, :bluesky_handle).transform_keys(&:to_s)])
    end

    it "finds people by a company, as the Contacts tab does" do
      create(:person, name: "Ada", company: "Analytical Engines")
      create(:person, name: "Grace")

      expect(list(query: "analytical").fetch("people").map { it.fetch("name") }).to eq(["Ada"])
    end

    it "matches only the name, key and handles for a token without contacts", :aggregate_failures do
      create(:person, name: "Ada", key: "countess", company: "Analytical Engines", emails: [{ value: "ada@x.io" }])

      expect(list(query: "analytical", token: open).fetch("people")).to eq([])
      expect(list(query: "ada@x.io", token: open).fetch("people")).to eq([])
      expect(list(query: "countess", token: open).fetch("people").map { it.fetch("name") }).to eq(["Ada"])
    end

    it "narrows to a label and to starred people" do
      create(:person, name: "Ada", labels: Sequel.pg_array(%w[Family], :text), starred: true)
      create(:person, name: "Grace")

      expect([list(label: "Family"), list(show: "starred")].map { it.fetch("people").map { it.fetch("name") } })
        .to eq([["Ada"], ["Ada"]])
    end

    it "refuses a label or starred from a token without contacts", :aggregate_failures do
      list(label: "Family", token: open)
      expect(insufficient).to eq(unscoped)

      list(show: "starred", token: open)
      expect(insufficient).to eq(unscoped)
    end

    it "keeps the mentionable people for a token without contacts" do
      create(:person, name: "Ada")
      create(:person, name: "Grace", key: nil, mastodon_handle: nil)

      expect(list(show: "mentionable", token: open).fetch("people").map { it.fetch("name") }).to eq(["Ada"])
    end

    it "answers an empty list with 200" do
      expect([list, status]).to eq([{ "people" => [] }, 200])
    end
  end

  describe "GET /api/v1/people/:id" do
    it "answers the person" do
      person = create(:person, name: "Ada Lovelace")

      expect(read(person.id)).to include("id" => person.id, "name" => "Ada Lovelace")
    end

    it "answers a token without contacts with only the open fields" do
      person = create(:person, name: "Ada Lovelace", phones: [{ value: "555-0100" }])

      expect(read(person.id, token: open).keys).to eq(%w[id key name mastodon_handle bluesky_handle])
    end
  end

  describe "POST /api/v1/people" do
    it "saves the person and answers them with 201", :aggregate_failures do
      added = add(name: "Ada Lovelace", key: " Ada ", mastodon_handle: "@ada@ruby.social")

      expect(added).to include("key" => "ada", "mastodon_handle" => "@ada@ruby.social", "bluesky_handle" => nil)
      expect([status, everyone.map(&:key)]).to eq([201, %w[ada]])
    end

    it "keeps the DID a Bluesky handle resolves to" do
      resolves("ada.bsky.social", "did:plc:ada")
      add(name: "Ada", key: "ada", bluesky_handle: "@Ada.Bsky.Social")

      expect(everyone.first).to have_attributes(bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada")
    end

    it "saves every private field it is given" do
      add(name: "Ada", **private_fields)

      expect(everyone.first).to have_attributes(private_fields)
    end

    it "refuses a private field from a token without contacts and saves nothing", :aggregate_failures do
      add(name: "Ada", company: "Analytical Engines", token: open)

      expect(insufficient).to eq(unscoped)
      expect(everyone).to be_empty
    end

    it "adds a person with only open fields on a token without contacts", :aggregate_failures do
      added = add(name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social", token: open)

      expect([status, added.keys]).to eq([201, %w[id key name mastodon_handle bluesky_handle]])
    end

    it "refuses an email address that is not one" do
      expect(add(name: "Ada", emails: [{ value: "not an address" }]).fetch("errors"))
        .to eq("emails" => ["an email address looks like ada@example.com"])
    end

    it "refuses a birthday that is not a date" do
      expect(add(name: "Ada", birthday: "December").fetch("errors"))
        .to eq("birthday" => ["a birthday looks like 1815-12-10, or --12-10 without the year"])
    end

    it "adds a person with no handle and no key", :aggregate_failures do
      expect([add(name: "Ada").values_at("name", "key"), status]).to eq([["Ada", nil], 201])
      expect(everyone.map(&:key)).to eq([nil])
    end

    it "refuses a handle with no key and saves nothing", :aggregate_failures do
      blank = "give a person with a handle a key"

      expect([add(name: "Ada", mastodon_handle: "@ada@ruby.social"), status])
        .to eq([{ "error" => "invalid", "message" => blank, "errors" => { "key" => [blank] } }, 422])
      expect(everyone).to be_empty
    end

    it "refuses a key that is not lowercase words" do
      expect(add(name: "Ada", key: "ada lovelace", mastodon_handle: "@ada@ruby.social").fetch("errors"))
        .to eq("key" => ["a key is lowercase words joined by hyphens"])
    end

    it "refuses a key someone else holds" do
      create(:person, key: "ada")

      expect(add(name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social").fetch("errors"))
        .to eq("key" => ["someone else already holds that key"])
    end

    it "refuses a blank name" do
      expect(add(name: " ", key: "ada", mastodon_handle: "@ada@ruby.social").fetch("errors"))
        .to eq("name" => ["give the person a name"])
    end

    it "refuses a name holding a control character" do
      expect(add(name: "A\u0000da", key: "ada", mastodon_handle: "@ada@ruby.social").fetch("errors"))
        .to eq("name" => ["name holds a control character"])
    end

    it "refuses a Mastodon handle that is not @user@instance" do
      expect(add(name: "Ada", key: "ada", mastodon_handle: "ada@ruby.social").fetch("errors"))
        .to eq("mastodon_handle" => ["a Mastodon handle looks like @ada@ruby.social"])
    end

    it "refuses a Bluesky handle Bluesky does not know", :aggregate_failures do
      unknown("nobody.bsky.social")

      expect(add(name: "Ada", key: "ada", bluesky_handle: "nobody.bsky.social").fetch("errors"))
        .to eq("bluesky_handle" => ["Bluesky knows no account by that handle"])
      expect(everyone).to be_empty
    end

    it "refuses a Bluesky handle while Bluesky does not answer" do
      stub_request(:get, %r{/com\.atproto\.identity\.resolveHandle}).to_return(status: 502)

      expect(add(name: "Ada", key: "ada", bluesky_handle: "ada.bsky.social").fetch("errors"))
        .to eq("bluesky_handle" => ["Bluesky did not answer; try again in a moment"])
    end
  end

  describe "PATCH /api/v1/people/:id" do
    let(:person) do
      create(:person, :bluesky, name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social",
                                bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada")
    end

    it "changes what it is given and keeps the rest" do
      expect(edit(person.id, name: "Ada Lovelace"))
        .to include("name" => "Ada Lovelace", "key" => "ada", "bluesky_handle" => "ada.bsky.social")
    end

    it "keeps the stored DID without asking Bluesky when the handle stays" do
      edit(person.id, name: "Ada Lovelace", bluesky_handle: "ada.bsky.social")

      expect(person_queries.by_id(person.id).bluesky_did).to eq("did:plc:ada")
    end

    it "clears a handle given as null, and its DID with it" do
      edit(person.id, bluesky_handle: nil)

      expect(person_queries.by_id(person.id)).to have_attributes(bluesky_handle: nil, bluesky_did: nil)
    end

    it "takes the last handle away and keeps the key" do
      edit(person.id, mastodon_handle: nil, bluesky_handle: nil)

      expect(person_queries.by_id(person.id))
        .to have_attributes(key: "ada", mastodon_handle: nil, bluesky_handle: nil, bluesky_did: nil)
    end

    it "refuses a key someone else holds" do
      create(:person, key: "grace")

      expect(edit(person.id, key: "grace").fetch("errors")).to eq("key" => ["someone else already holds that key"])
    end

    it "changes a private field and keeps the rest" do
      expect(edit(person.id, notes: "Wrote the first program"))
        .to include("notes" => "Wrote the first program", "name" => "Ada")
    end

    it "refuses a private field from a token without contacts and changes nothing", :aggregate_failures do
      edit(person.id, name: "Ada Lovelace", notes: "Wrote the first program", token: open)

      expect(insufficient).to eq(unscoped)
      expect(person_queries.by_id(person.id)).to have_attributes(name: "Ada", notes: nil)
    end

    it "changes an open field on a token without contacts" do
      expect(edit(person.id, name: "Ada Lovelace", token: open)).to include("name" => "Ada Lovelace")
    end
  end

  describe "DELETE /api/v1/people/:id" do
    it "removes the person", :aggregate_failures do
      person = create(:person)

      expect(remove(person.id)).to eq("id" => person.id, "deleted" => true)
      expect(everyone).to be_empty
    end

    it "refuses a token without contacts and keeps the person", :aggregate_failures do
      person = create(:person)
      remove(person.id, token: open)

      expect(insufficient).to eq(unscoped)
      expect(everyone.map(&:id)).to eq([person.id])
    end
  end

  describe "POST /api/v1/people/sync" do
    it "queues a contact sync" do
      expect([sync, Contacts::Jobs::SyncContacts.jobs.size]).to eq([{ "status" => "queued" }, 1])
    end

    it "refuses a token without contacts" do
      sync(token: open)

      expect(insufficient).to eq(unscoped)
    end

    it "answers 503 while the queue is down" do
      allow(Contacts::Jobs::SyncContacts).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)

      expect([sync.fetch("error"), status]).to eq(["unavailable", 503])
    end
  end

  describe "a contact linked to Google" do
    let(:api) { Contacts::Helpers::GooglePerson::API }
    let(:person) do
      create(:person, name: "Ada", key: "ada", google_connection_id: connect_contacts.id, google_id: "c1",
                      google_etag: "e1")
    end

    before { stub_contact_groups }

    it "sends a new contact to Google" do
      connect_contacts
      stub_request(:post, /createContact/).to_return(google_health_json(google_contact("c9", "Ada")))
      add(name: "Ada")

      expect(everyone.first).to have_attributes(google_id: "c9", google_etag: "e1")
    end

    it "removes the contact from Google" do
      stub_request(:delete, "#{api}/people/c1:deleteContact").to_return(status: 200, body: "{}")
      remove(person.id)

      expect(a_request(:delete, "#{api}/people/c1:deleteContact")).to have_been_made
    end

    it "refuses an edit with 409 when Google changed it first", :aggregate_failures do
      newer = google_contact("c1", "Ada King", etag: "e2")
      stub_request(:get, %r{\A#{api}/people/c1\?}).to_return(google_health_json(newer))

      expect(edit(person.id, name: "Ada Lovelace"))
        .to eq("error" => "conflict", "message" => API::Endpoints::People::CONFLICT)
      expect(last_response.status).to eq(409)
    end

    it "answers 503 when Google refuses the delete", :aggregate_failures do
      stub_request(:delete, "#{api}/people/c1:deleteContact").to_return(status: 500)

      expect(remove(person.id)).to eq("error" => "unavailable", "message" => API::Endpoints::People::GOOGLE_DOWN)
      expect(last_response.status).to eq(503)
    end
  end

  describe "GET /api/v1/people/search/:network" do
    let(:ada) { { avatar: "https://cdn.bsky.app/ada.jpg", displayName: "Ada Lovelace", handle: "ada.bsky.social" } }

    before { connect_social_networks }

    it "answers the Bluesky accounts the admin's search finds" do
      stub_bluesky_search("ada", ada)

      expect(search("bluesky", "ada"))
        .to eq("accounts" => [{ "handle" => "ada.bsky.social", "name" => "Ada Lovelace",
                                "avatar" => "https://cdn.bsky.app/ada.jpg" }])
    end

    it "names a Mastodon account as @user@instance" do
      stub_mastodon_search("grace", { acct: "grace@hachyderm.io", avatar: nil, display_name: "Grace Hopper" })

      expect(search("mastodon", "grace").fetch("accounts"))
        .to eq([{ "handle" => "@grace@hachyderm.io", "name" => "Grace Hopper", "avatar" => nil }])
    end

    it "asks no network for a query shorter than two characters", :aggregate_failures do
      expect(search("bluesky", " a ")).to eq("accounts" => [])
      expect(a_request(:get, /searchActorsTypeahead/)).not_to have_been_made
    end

    it "refuses a network with no credentials with a 503" do
      connect_social_networks(bluesky: {})

      expect([search("bluesky", "ada"), status]).to eq(
        [{ "error" => "unavailable", "message" => "Bluesky has no credentials, so it cannot be searched" }, 503],
      )
    end

    it "refuses a network that rate limits with a 503" do
      stub_mastodon_search("grace", status: 429)
      message = "Mastodon has had too many searches; wait a minute and try again"

      expect([search("mastodon", "grace"), status]).to eq([{ "error" => "unavailable", "message" => message }, 503])
    end

    it "lists 503 in the OpenAPI document" do
      expect(OpenAPI.document.dig("paths", "/people/search/{network}", "get", "responses")).to include("503")
    end

    it "refuses a network that does not answer" do
      stub_bluesky_search("ada", status: 502)

      expect(search("bluesky", "ada").fetch("message")).to eq("Bluesky did not answer; try again")
    end

    it "refuses a network it does not know with a 422" do
      search("myspace", "ada")

      expect(status).to eq(422)
    end
  end

  describe "the MCP tools" do
    def mcp_scopes = [*MCPToolCalls::SCOPES.split, "contacts"]

    it "list and search as list_people does" do
      create(:person, name: "Ada", company: "Analytical Engines")

      expect(mcp_answer("list_people", query: "analytical")).to eq(list(query: "analytical"))
    end

    it "sync as sync_people does", :aggregate_failures do
      expect(mcp_answer("sync_people")).to eq(sync)
      expect(Contacts::Jobs::SyncContacts.jobs.size).to eq(2)
    end

    it "save every private field as save_person does", :aggregate_failures do
      fields = { name: "Ada", phones: [{ value: "555-0100", type: "mobile" }], birthday: "--12-10" }
      added = add(**fields)
      remove(added.fetch("id"))

      expect(mcp_answer("save_person", **fields)).to include(added.except("id", "created_at", "updated_at"))
      expect(everyone.map(&:phones)).to eq([[{ "value" => "555-0100", "type" => "mobile" }]])
    end

    it "refuse an edit Google changed first, as the endpoint does" do
      person = create(:person, google_connection_id: connect_contacts.id, google_id: "c1", google_etag: "e1")
      stub_contact_groups
      stub_request(:get, %r{/people/c1\?}).to_return(google_health_json(google_contact("c1", "Ada", etag: "e2")))

      expect(mcp_text("save_person", id: person.id, name: "Ada King")).to eq(API::Endpoints::People::CONFLICT)
    end

    it "list as list_people does" do
      create(:person)

      expect(mcp_answer("list_people")).to eq(list)
    end

    it "read as read_person does" do
      person = create(:person)

      expect(mcp_answer("read_person", id: person.id)).to eq(read(person.id))
    end

    it "add as save_person does with no id" do
      added = add(name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social")
      remove(added.fetch("id"))

      expect(mcp_answer("save_person", name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social"))
        .to include(added.except("id", "created_at", "updated_at"))
    end

    it "edit as save_person does with an id", :aggregate_failures do
      person = create(:person, name: "Ada")
      edited = mcp_answer("save_person", id: person.id, name: "Ada Lovelace")

      expect(edited).to eq(read(person.id))
      expect(edited.fetch("name")).to eq("Ada Lovelace")
    end

    it "refuse what the admin form refuses, with the message the endpoint gives" do
      refused = add(name: "Ada", mastodon_handle: "@ada@ruby.social")
      answer = mcp_call("save_person", name: "Ada", mastodon_handle: "@ada@ruby.social")

      expect([answer["isError"], answer.dig("content", 0, "text")]).to eq([true, refused.fetch("message")])
    end

    it "delete as delete_person does", :aggregate_failures do
      person = create(:person)

      expect(mcp_answer("delete_person", id: person.id)).to eq("id" => person.id, "deleted" => true)
      expect(everyone).to be_empty
    end

    it "answer a missing person with the message the endpoint gives" do
      expect(mcp_text("read_person", id: 999_999)).to eq("no person has the ID 999999")
    end

    describe "without the contacts permission" do
      def mcp_scopes = MCPToolCalls::SCOPES.split

      it "list and read only the open fields", :aggregate_failures do
        person = create(:person, company: "Analytical Engines")

        expect(mcp_answer("list_people")).to eq(list(token: open))
        expect(mcp_answer("read_person", id: person.id)).to eq(read(person.id, token: open))
      end

      it "refuse a private field in save_person, naming contacts", :aggregate_failures do
        answer = mcp_call("save_person", name: "Ada", company: "Analytical Engines")

        expect([answer["isError"], answer.dig("content", 0, "text")])
          .to eq([true, "this endpoint needs a token with the contacts scope"])
        expect(everyone).to be_empty
      end

      it "save the open fields" do
        expect(mcp_answer("save_person", name: "Ada", key: "ada").keys)
          .to eq(%w[id key name mastodon_handle bluesky_handle])
      end

      it "withhold delete_person and sync_people", :aggregate_failures do
        mcp_rpc("tools/list")

        expect(mcp_result.fetch("tools").map { it.fetch("name") }).not_to include("delete_person", "sync_people")
      end
    end

    describe "search_accounts" do
      before { connect_social_networks }

      it "searches as the endpoint does, with each name marked untrusted" do
        stub_bluesky_search("ada", { avatar: nil, displayName: "Ada", handle: "ada.bsky.social" })
        marked = search("bluesky", "ada").fetch("accounts").map do |account|
          account.merge("name" => { "untrusted" => true, "text" => account.fetch("name") })
        end

        expect(mcp_answer("search_accounts", network: "bluesky", query: "ada")).to eq("accounts" => marked)
      end

      it "refuses a network with no credentials" do
        connect_social_networks(mastodon: {})

        expect(mcp_text("search_accounts", network: "mastodon", query: "grace"))
          .to eq("Mastodon has no credentials, so it cannot be searched")
      end

      it "refuses a network that rate limits" do
        stub_bluesky_search("ada", status: 429)

        expect(mcp_call("search_accounts", network: "bluesky", query: "ada")["isError"]).to be(true)
      end
    end
  end
end
