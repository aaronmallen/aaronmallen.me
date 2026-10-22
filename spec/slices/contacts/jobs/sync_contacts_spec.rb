# frozen_string_literal: true

RSpec.describe Contacts::Jobs::SyncContacts do
  let(:scope) { Contacts::Operations::SyncContacts::SCOPE }

  def api = Contacts::Helpers::GooglePerson::API

  def connect(account, token, sync_contacts: true, scopes: [scope])
    connect_google(account_id: account, scopes:, token:, sync_contacts:)
  end

  def contact(id, name, **fields)
    {
      resourceName: "people/#{id}", names: [{ displayName: name, metadata: { primary: true } }],
      memberships: [], **fields,
    }
  end

  def failure = sync_state_queries.failure(sync)

  def google_json(body) = { body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def people = Contacts::Slice["relations.people"].order(:google_id).to_a

  def run = described_class.new.perform

  def stub_contacts(token, *connections, query: {}, **body)
    stub_request(:get, %r{\A#{api}/people/me/connections\?})
      .with(headers: { "Authorization" => "Bearer #{token}" }, query: hash_including(query))
      .to_return(google_json(connections:, **body))
  end

  def stub_groups(token, *groups)
    stub_request(:get, %r{\A#{api}/contactGroups\?}).with(headers: { "Authorization" => "Bearer #{token}" })
                                                    .to_return(google_json(contactGroups: groups))
  end

  def sync = Blog::Types::SyncName["contacts"]

  def tokens = Contacts::Slice["repos.person_queries"].sync_tokens

  describe "with an account that syncs contacts" do
    let(:connection) { connect("me@example.com", "ya29.me") }

    def ada
      contact(
        "c1", "Ada Lovelace",
        names: [{
          displayName: "Ada Lovelace", givenName: "Ada", familyName: "Lovelace", honorificPrefix: "Countess",
          metadata: { primary: true },
        }],
        nicknames: [{ value: "Ada" }], fileAses: [{ value: "Lovelace, Ada" }],
        organizations: [{ name: "Analytical Engines", title: "Analyst", department: "Notes" }],
        biographies: [{ value: "Wrote the first program" }],
        emailAddresses: [{ value: "ada@example.com", type: "work" }, { value: " " }],
        phoneNumbers: [{ value: "+44 20 7946 0000", type: "mobile" }],
        addresses: [{ streetAddress: "12 St James's Square", city: "London", country: "UK", type: "home" }, {}],
        urls: [{ value: "https://ada.example.com", type: "blog" }],
        imClients: [{ username: "ada", protocol: "jabber", formattedProtocol: "Jabber" }],
        birthdays: [{ date: { year: 1815, month: 12, day: 10 } }],
        events: [{ date: { month: 6, day: 8 }, type: "anniversary" }, { date: { year: 1840 } }],
        relations: [{ person: "Byron", type: "father" }],
        userDefined: [{ key: "Engine", value: "Difference" }],
        memberships: [
          { contactGroupMembership: { contactGroupResourceName: "contactGroups/starred" } },
          { contactGroupMembership: { contactGroupResourceName: "contactGroups/abc" } },
          { contactGroupMembership: { contactGroupResourceName: "contactGroups/myContacts" } },
        ],
      )
    end

    before do
      connection
      stub_groups(
        "ya29.me",
        { resourceName: "contactGroups/abc", name: "speaking", groupType: "USER_CONTACT_GROUP" },
        { resourceName: "contactGroups/myContacts", name: "myContacts", groupType: "SYSTEM_CONTACT_GROUP" },
      )
      stub_contacts("ya29.me", ada, contact("c2", "Grace Hopper"), nextSyncToken: "first")
    end

    it_behaves_like "a sync that steps aside while it runs"

    it "keeps every field Google holds for each contact" do
      run

      expect(people.first).to include(stored_ada)
    end

    def stored_ada
      {
        google_connection_id: connection.id, google_id: "c1", name: "Ada Lovelace", given_name: "Ada",
        family_name: "Lovelace", name_prefix: "Countess", nickname: "Ada", file_as: "Lovelace, Ada",
        company: "Analytical Engines", job_title: "Analyst", department: "Notes", notes: "Wrote the first program",
        emails: [{ "value" => "ada@example.com", "type" => "work" }],
        phones: [{ "value" => "+44 20 7946 0000", "type" => "mobile" }],
        addresses: [{ "street" => "12 St James's Square", "city" => "London", "country" => "UK", "type" => "home" }],
        websites: [{ "value" => "https://ada.example.com", "type" => "blog" }],
        chats: [{ "value" => "ada", "type" => "Jabber" }], birthday: "1815-12-10",
        dates: [{ "value" => "--06-08", "type" => "anniversary" }],
        relations: [{ "value" => "Byron", "type" => "father" }],
        custom_fields: [{ "key" => "Engine", "value" => "Difference" }],
      }
    end

    it "takes labels from my contact groups and the star from favorites" do
      run

      expect(people.map { it.values_at(:labels, :starred) }).to eq([[["speaking"], true], [[], false]])
    end

    it "asks Google for a sync token and keeps it" do
      run

      expect(tokens).to eq(connection.id => "first")
    end

    it "reads the whole address book on the first run" do
      run

      expect(a_request(:get, %r{/people/me/connections}).with(query: hash_including("requestSyncToken" => "true")))
        .to have_been_made
    end

    it "records no failure" do
      run

      expect(failure).to be_nil
    end

    it "skips a contact with neither a name nor a company" do
      stub_contacts("ya29.me", ada, { resourceName: "people/c9", emailAddresses: [{ value: "x@example.com" }] })
      run

      expect(people.map { it[:google_id] }).to eq(["c1"])
    end

    it "keeps a contact named only by its company" do
      stub_contacts("ya29.me", { resourceName: "people/c9", organizations: [{ name: "Acme" }] })
      run

      expect(people.map { it.values_at(:name, :company) }).to eq([[nil, "Acme"]])
    end

    describe "on the next run" do
      before do
        run
        Contacts::Slice["relations.people"].where(google_id: "c1").update(key: "ada",
                                                                          mastodon_handle: "@ada@ruby.social")
      end

      def stub_changes = stub_contacts("ya29.me", *changes, query: { "syncToken" => "first" }, nextSyncToken: "second")

      let(:changes) do
        [
          contact("c1", "Ada King", urls: [{ value: "https://ruby.social/@someone", type: "profile" }]),
          { resourceName: "people/c2", metadata: { deleted: true } },
          contact("c3", "Katherine Johnson"),
        ]
      end

      it "asks only for what changed since the last token" do
        stub_changes
        run

        expect(a_request(:get, %r{/people/me/connections}).with(query: hash_including("syncToken" => "first")))
          .to have_been_made
      end

      it "updates changed contacts and adds new ones" do
        stub_changes
        run

        expect(people.map { it.values_at(:google_id, :name) }).to eq([["c1", "Ada King"], ["c3", "Katherine Johnson"]])
      end

      it "removes a contact deleted in Google" do
        stub_changes
        run

        expect(people.map { it[:google_id] }).not_to include("c2")
      end

      it "keeps the key and handles stored here" do
        stub_changes
        run

        expect(people.first.values_at(:key, :mastodon_handle)).to eq(["ada", "@ada@ruby.social"])
      end

      it "moves to the new token" do
        stub_changes
        run

        expect(tokens).to eq(connection.id => "second")
      end

      describe "when Google answers that the token expired" do
        before do
          expired = { error: { status: "FAILED_PRECONDITION", details: [{ reason: "EXPIRED_SYNC_TOKEN" }] } }
          stub_request(:get, %r{\A#{api}/people/me/connections\?.*syncToken=first})
            .to_return(status: 400, **google_json(expired))
          stub_request(:get, %r{\A#{api}/people/me/connections\?})
            .with { !it.uri.query.include?("syncToken") }
            .to_return(google_json(connections: [contact("c3", "Katherine Johnson")], nextSyncToken: "fresh"))
          run
        end

        it "reads the whole address book again and drops what it no longer holds" do
          expect(people.map { it[:google_id] }).to eq(["c3"])
        end

        it("starts over from the new token") { expect(tokens.values).to eq(["fresh"]) }

        it("records no failure") { expect(failure).to be_nil }
      end

      describe "when Google keeps failing" do
        before do
          stub_request(:get, %r{\A#{api}/people/me/connections\?}).to_return(status: 503)
          run
        end

        it "tries the whole address book once before it gives up" do
          full = a_request(:get, %r{/people/me/connections}).with { !it.uri.query.include?("syncToken") }

          expect(full).to have_been_made.twice
        end

        it("records the failure") { expect(failure).to include(reason: "google_contacts_failed") }

        it("keeps what it held") { expect(people.map { it[:google_id] }).to eq(%w[c1 c2]) }
      end

      describe "when Google answers 410 Gone" do
        before do
          stub_request(:get, %r{\A#{api}/people/me/connections\?.*syncToken=first}).to_return(status: 410)
          stub_request(:get, %r{\A#{api}/people/me/connections\?})
            .with { !it.uri.query.include?("syncToken") }
            .to_return(google_json(connections: [], nextSyncToken: "fresh"))
          run
        end

        it("starts over") { expect([people, tokens.values]).to eq([[], ["fresh"]]) }
      end
    end

    describe "when Google fails" do
      before do
        stub_request(:get, %r{\A#{api}/people/me/connections\?}).to_return(status: 503)
        run
      end

      it "records the failure" do
        expect(failure).to include(reason: "google_contacts_failed", message: "Google answered 503")
      end

      it("keeps no token") { expect(tokens).to be_empty }
    end
  end

  it "leaves an account that has not opted in alone", :aggregate_failures do
    connect("me@example.com", "ya29.me", sync_contacts: false)
    run

    expect(a_request(:any, /googleapis\.com/)).not_to have_been_made
    expect(people).to be_empty
  end

  it "leaves an account without the contacts scope alone" do
    connect("me@example.com", "ya29.me", scopes: Spec::GoogleAccounts::HEALTH_SCOPES)
    run

    expect(a_request(:any, /googleapis\.com/)).not_to have_been_made
  end

  describe "with two accounts that sync contacts" do
    let!(:mine) { connect("me@example.com", "ya29.me") }
    let!(:theirs) { connect("other@example.com", "ya29.other") }

    before do
      %w[ya29.me ya29.other].each { stub_groups(it) }
      stub_contacts("ya29.me", contact("c1", "Ada Lovelace"), nextSyncToken: "mine")
      stub_contacts("ya29.other", contact("c1", "Ada King"), nextSyncToken: "theirs")
      run
    end

    it "keeps each account's copy of a contact apart" do
      expect(people.map { it.values_at(:google_connection_id, :name) })
        .to contain_exactly([mine.id, "Ada Lovelace"], [theirs.id, "Ada King"])
    end

    it("keeps a token for each") { expect(tokens).to eq(mine.id => "mine", theirs.id => "theirs") }
  end

  describe "with a person no Google account holds" do
    before do
      create(:person, key: "local")
      connect("me@example.com", "ya29.me")
      stub_groups("ya29.me")
      stub_contacts("ya29.me", nextSyncToken: "first")
      run
    end

    it("keeps them") { expect(people.map { it[:key] }).to eq(["local"]) }
  end

  describe "a run that crashes" do
    before { replace_component("operations.sync_contacts", ->(*) { raise KeyError, "key not found: :id" }) }

    def run_crashing
      run
    rescue KeyError
      nil
    end

    it "records the crash where the admin reads it" do
      run_crashing

      expect(failure).to include(reason: "crashed", message: "key not found: :id")
    end
  end
end
