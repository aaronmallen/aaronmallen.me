# frozen_string_literal: true

RSpec.describe "API people", type: :request do
  let(:repo) { Social::Slice["repos.person_repo"] }

  def add(fields) = call_api(:post, "", JSON.generate(fields))

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil, query: nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/people#{path}", query || body, headers)
    JSON.parse(last_response.body)
  end

  def edit(id, fields) = call_api(:patch, "/#{id}", JSON.generate(fields))

  def everyone = repo.all

  def json_of(person)
    stamps = person.to_h.slice(:created_at, :updated_at).transform_values { it.utc.iso8601 }

    person.to_h.slice(:id, :key, :name, :mastodon_handle, :bluesky_handle).merge(stamps).transform_keys(&:to_s)
  end

  def list = call_api(:get, "")

  def read(id) = call_api(:get, "/#{id}")

  def remove(id) = call_api(:delete, "/#{id}")

  def resolves(handle, did)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(did:))
  end

  def search(network, text) = call_api(:get, "/search/#{network}", query: { query: text })

  def status = last_response.status

  def unknown(handle)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(status: 400, error: "InvalidRequest", message: "Unable to resolve handle"))
  end

  describe "GET /api/v1/people" do
    it "lists everyone by name" do
      create(:person, name: "Grace Hopper")
      create(:person, name: "Ada Lovelace")

      expect(list.fetch("people").map { it.fetch("name") }).to eq(["Ada Lovelace", "Grace Hopper"])
    end

    it "gives each person's id, key, name, handles and times" do
      ada = create(:person, :bluesky, mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social")

      expect(list.fetch("people")).to eq([json_of(ada)])
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

    it "answers an unknown ID with a 404" do
      expect([read(404), status]).to eq([{ "error" => "not_found", "message" => "no person has the ID 404" }, 404])
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

    it "refuses a person with no handle and saves nothing", :aggregate_failures do
      none = "give the person at least one handle"

      expect([add(name: "Ada", key: "ada"), status])
        .to eq([{ "error" => "invalid", "message" => none, "errors" => { "handles" => [none] } }, 422])
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

    it "refuses a person with no key" do
      expect(add(name: "Ada", mastodon_handle: "@ada@ruby.social").fetch("errors")).to eq("key" => ["key is missing"])
    end

    it "answers a failure it did not expect with a 500" do
      failing = instance_double(Social::Operations::SavePerson, call: Dry::Monads::Failure(:unexpected))
      replace_component("social.operations.save_person", failing)

      expect([add(name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social"), status])
        .to eq([{ "error" => "failed", "message" => "could not save the person" }, 500])
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

      expect(repo.by_id(person.id).bluesky_did).to eq("did:plc:ada")
    end

    it "clears a handle given as null, and its DID with it" do
      edit(person.id, bluesky_handle: nil)

      expect(repo.by_id(person.id)).to have_attributes(bluesky_handle: nil, bluesky_did: nil)
    end

    it "refuses to take the last handle away", :aggregate_failures do
      edit(person.id, mastodon_handle: nil, bluesky_handle: nil)

      expect(status).to eq(422)
      expect(repo.by_id(person.id).bluesky_handle).to eq("ada.bsky.social")
    end

    it "refuses a key someone else holds" do
      create(:person, key: "grace")

      expect(edit(person.id, key: "grace").fetch("errors")).to eq("key" => ["someone else already holds that key"])
    end

    it "answers an unknown ID with a 404" do
      expect([edit(404, name: "Ada"), status])
        .to eq([{ "error" => "not_found", "message" => "no person has the ID 404" }, 404])
    end
  end

  describe "DELETE /api/v1/people/:id" do
    it "removes the person", :aggregate_failures do
      person = create(:person)

      expect(remove(person.id)).to eq("id" => person.id, "deleted" => true)
      expect(everyone).to be_empty
    end

    it "answers an unknown ID with a 404" do
      expect([remove(404), status]).to eq([{ "error" => "not_found", "message" => "no person has the ID 404" }, 404])
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

    it "refuses a network with no credentials with a 404" do
      connect_social_networks(bluesky: {})

      expect([search("bluesky", "ada"), status]).to eq(
        [{ "error" => "not_found", "message" => "Bluesky has no credentials, so it cannot be searched" }, 404],
      )
    end

    it "refuses a network that rate limits" do
      stub_mastodon_search("grace", status: 429)

      expect([search("mastodon", "grace"), status]).to eq(
        [{ "error" => "failed", "message" => "Mastodon has had too many searches; wait a minute and try again" }, 500],
      )
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
      refused = add(name: "Ada", key: "ada")
      answer = mcp_call("save_person", name: "Ada", key: "ada")

      expect([answer["isError"], answer.dig("content", 0, "text")]).to eq([true, refused.fetch("message")])
    end

    it "delete as delete_person does", :aggregate_failures do
      person = create(:person)

      expect(mcp_answer("delete_person", id: person.id)).to eq("id" => person.id, "deleted" => true)
      expect(everyone).to be_empty
    end

    it "answer a missing person with the message the endpoint gives" do
      expect(mcp_text("read_person", id: 404)).to eq("no person has the ID 404")
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
