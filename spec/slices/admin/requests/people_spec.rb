# frozen_string_literal: true

RSpec.describe "Admin people", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Social::Slice["repos.person_repo"] }

  def add(**fields) = send_to("/admin/people", person: { **blank, **fields })

  def blank = { name: "", key: "", mastodon_handle: "", bluesky_handle: "" }

  def error(field, code) = i18n.t(["ui.components.people.field_error", field, code].join("."))

  def everyone = repo.all

  def resolves(handle, did)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(did:))
  end

  def send_to(path, **params) = post(path, { _csrf_token: admin_csrf_token, **params })

  def unknown(handle)
    stub_request(:get, "#{SocialNetworks::BLUESKY_PUBLIC}/com.atproto.identity.resolveHandle")
      .with(query: { handle: })
      .to_return(**json_response(status: 400, error: "InvalidRequest", message: "Unable to resolve handle"))
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "is a section of the command palette" do
      get "/admin"

      expect(page).to have_css("[data-palette-href='/admin/people']", visible: :all)
    end

    describe "the list" do
      it "says something useful when there is nobody yet" do
        get "/admin/people"

        expect(page).to have_css(".empty", text: "Nobody yet")
      end

      it "lists everyone in name order" do
        create(:person, name: "Grace Hopper")
        create(:person, name: "Ada Lovelace")
        get "/admin/people"

        expect(page.all(".li-title").map(&:text)).to eq(["Ada Lovelace", "Grace Hopper"])
      end

      it "shows the token and each handle a person has" do
        create(:person, :bluesky, key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social")
        get "/admin/people"

        expect(page.find(".li-sub").text).to eq("@{ada} · @ada@ruby.social · @ada.bsky.social")
      end

      it "links each person to their editor" do
        person = create(:person)
        get "/admin/people"

        expect(page).to have_css("a.li-title[href='/admin/people/#{person.id}/edit']")
      end

      it "links to the form for a new person" do
        get "/admin/people"

        expect(page).to have_link(href: "/admin/people/new")
      end
    end

    describe "adding a person" do
      it "draws the form with no script" do
        get "/admin/people/new"

        expect(page).to have_css("form[method='post'][action='/admin/people'] input[name='person[key]']")
      end

      it "stores a person with a Mastodon handle" do
        add(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(everyone.map { [it.name, it.key, it.mastodon_handle, it.bluesky_handle] })
          .to eq([["Ada Lovelace", "ada", "@ada@ruby.social", nil]])
      end

      it "goes back to the list and says so", :aggregate_failures do
        add(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")
        follow_redirect!

        expect(last_request.path).to eq("/admin/people")
        expect(page).to have_css("[data-toast]", text: "Person added")
      end

      it "folds the key to one case" do
        add(name: "Ada", key: " Ada ", mastodon_handle: "@ada@ruby.social")

        expect(everyone.map(&:key)).to eq(%w[ada])
      end

      it "stores the DID a Bluesky handle resolves to", :aggregate_failures do
        resolves("ada.bsky.social", "did:plc:ada")
        add(name: "Ada", key: "ada", bluesky_handle: "ada.bsky.social")

        expect(everyone.first).to have_attributes(bluesky_handle: "ada.bsky.social", bluesky_did: "did:plc:ada")
        expect(everyone.first.mastodon_handle).to be_nil
      end

      it "takes a Bluesky handle typed with an @ and in capitals" do
        resolves("ada.bsky.social", "did:plc:ada")
        add(name: "Ada", key: "ada", bluesky_handle: "@Ada.Bsky.Social")

        expect(everyone.first.bluesky_handle).to eq("ada.bsky.social")
      end

      it "looks a handle up without Bluesky credentials" do
        resolves("ada.bsky.social", "did:plc:ada")
        add(name: "Ada", key: "ada", bluesky_handle: "ada.bsky.social")

        expect(Social::Slice["networks.all"].fetch("bluesky")).not_to be_configured
      end

      it "stores both handles for someone on both networks" do
        resolves("ada.bsky.social", "did:plc:ada")
        add(name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.bsky.social")

        expect(everyone.first).to have_attributes(mastodon_handle: "@ada@ruby.social", bluesky_did: "did:plc:ada")
      end

      it "refuses a person with no handle", :aggregate_failures do
        add(name: "Ada", key: "ada")

        expect(last_response.status).to eq(422)
        expect(page).to have_css("#person-handles-error", text: error(:handles, :none))
        expect(everyone).to be_empty
      end

      it "refuses a blank name" do
        add(key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(page).to have_css("#person-name-error", text: error(:name, :blank))
      end

      it "refuses a blank key" do
        add(name: "Ada", mastodon_handle: "@ada@ruby.social")

        expect(page).to have_css("#person-key-error", text: error(:key, :blank))
      end

      ["ada lovelace", "ada_l", "-ada", "@{ada}"].each do |key|
        it "refuses the key #{key.inspect}", :aggregate_failures do
          add(name: "Ada", key:, mastodon_handle: "@ada@ruby.social")

          expect(page).to have_css("#person-key-error", text: error(:key, :format))
          expect(everyone).to be_empty
        end
      end

      it "refuses a key someone else holds", :aggregate_failures do
        create(:person, key: "ada")
        add(name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(last_response.status).to eq(422)
        expect(page).to have_css("#person-key-error", text: error(:key, :taken))
      end

      ["ada@ruby.social", "@ada", "@ada@", "ada", "@ada@ruby", "@ada@ruby.social@x.y", "@a da@ruby.social"]
        .each do |handle|
          it "refuses the Mastodon handle #{handle.inspect}", :aggregate_failures do
            add(name: "Ada", key: "ada", mastodon_handle: handle)

            expect(page).to have_css("#person-mastodon_handle-error", text: error(:mastodon_handle, :format))
            expect(everyone).to be_empty
          end
        end

      it "refuses a Bluesky handle that is not a domain" do
        add(name: "Ada", key: "ada", bluesky_handle: "ada")

        expect(page).to have_css("#person-bluesky_handle-error", text: error(:bluesky_handle, :format))
      end

      it "refuses a Bluesky handle that resolves to nobody, beside the field", :aggregate_failures do
        unknown("nobody.bsky.social")
        add(name: "Ada", key: "ada", bluesky_handle: "nobody.bsky.social")

        expect(page).to have_css("#person-bluesky_handle[aria-invalid='true']")
        expect(page).to have_css("#person-bluesky_handle + .field-error", text: error(:bluesky_handle, :unresolved))
        expect(everyone).to be_empty
      end

      it "refuses a Bluesky handle while Bluesky does not answer", :aggregate_failures do
        stub_request(:get, %r{/com\.atproto\.identity\.resolveHandle}).to_return(status: 502)
        add(name: "Ada", key: "ada", bluesky_handle: "ada.bsky.social")

        expect(page).to have_css("#person-bluesky_handle-error", text: error(:bluesky_handle, :unreachable))
        expect(everyone).to be_empty
      end

      it "keeps what was typed after a refusal" do
        add(name: "Ada Lovelace", key: "ada lovelace", mastodon_handle: "@ada@ruby.social")

        expect(page).to have_field("person[name]", with: "Ada Lovelace")
      end
    end

    describe "adding a person from the social composer" do
      def mention(**fields) = send_to("/admin/people", reply: "mention", person: { **blank, **fields })

      it "answers with the new option for the mention list", :aggregate_failures do
        mention(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(last_response.status).to eq(201)
        expect(page).to have_css(
          "[role='option'][data-social-mention='ada'][data-social-mention-in='mastodon']", text: "Ada Lovelace",
        )
      end

      it "answers with the handles each network shows" do
        mention(name: "Ada Lovelace", key: "ada", mastodon_handle: "@ada@ruby.social")

        expect(JSON.parse(page.find("[data-social-people]", visible: :all)["data-social-people"]))
          .to eq("mastodon" => { "ada" => "@ada@ruby.social" }, "bluesky" => { "ada" => "Ada Lovelace" })
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

      it "answers a refusal with the form and its errors", :aggregate_failures do
        mention(name: "Ada", key: "ada")

        expect(last_response.status).to eq(422)
        expect(page).to have_css("form[data-person-form='new'] #person-handles-error", text: error(:handles, :none))
      end
    end

    describe "the form" do
      def fields(path)
        get path
        Capybara.string(last_response.body).all("form[data-person-form] input:not([type=hidden])").map { it[:name] }
      end

      it "draws the same fields to add and to edit a person" do
        expect(fields("/admin/people/#{create(:person).id}/edit")).to eq(fields("/admin/people/new"))
      end

      it "marks the form for a new person so the key can follow the name" do
        get "/admin/people/new"

        expect(page).to have_css("form[data-person-form='new']")
      end

      it "marks the form for a stored person so the key stays put" do
        get "/admin/people/#{create(:person).id}/edit"

        expect(page).to have_css("form[data-person-form='edit']")
      end
    end

    describe "editing a person" do
      let(:person) do
        create(:person, :bluesky, name: "Ada", key: "ada", mastodon_handle: nil, bluesky_handle: "ada.bsky.social")
      end

      def save(**fields)
        stored = person.to_h.slice(:name, :key, :mastodon_handle, :bluesky_handle)

        send_to("/admin/people/#{person.id}", person: stored.merge(fields))
      end

      it "fills the form with what is stored" do
        get "/admin/people/#{person.id}/edit"

        expect(page).to have_field("person[bluesky_handle]", with: "ada.bsky.social")
      end

      it "saves a change and says so", :aggregate_failures do
        save(name: "Ada Lovelace")
        follow_redirect!

        expect(repo.by_id(person.id).name).to eq("Ada Lovelace")
        expect(page).to have_css("[data-toast]", text: "Person saved")
      end

      it "keeps the stored DID without asking Bluesky when the handle stays" do
        save(name: "Ada Lovelace")

        expect(repo.by_id(person.id).bluesky_did).to eq(person.bluesky_did)
      end

      it "resolves a new Bluesky handle" do
        resolves("lovelace.example", "did:plc:lovelace")
        save(bluesky_handle: "lovelace.example")

        expect(repo.by_id(person.id))
          .to have_attributes(bluesky_handle: "lovelace.example", bluesky_did: "did:plc:lovelace")
      end

      it "drops the DID with the Bluesky handle" do
        save(mastodon_handle: "@ada@ruby.social", bluesky_handle: "")

        expect(repo.by_id(person.id)).to have_attributes(bluesky_handle: nil, bluesky_did: nil)
      end

      it "refuses to take the last handle away", :aggregate_failures do
        save(bluesky_handle: "")

        expect(last_response.status).to eq(422)
        expect(repo.by_id(person.id).bluesky_handle).to eq("ada.bsky.social")
      end

      it "refuses a new handle that resolves to nobody", :aggregate_failures do
        unknown("nobody.example")
        save(bluesky_handle: "nobody.example")

        expect(page).to have_css("#person-bluesky_handle-error", text: error(:bluesky_handle, :unresolved))
        expect(repo.by_id(person.id).bluesky_handle).to eq("ada.bsky.social")
      end

      it "refuses a key someone else holds" do
        create(:person, key: "grace")
        save(key: "grace")

        expect(page).to have_css("#person-key-error", text: error(:key, :taken))
      end

      it "answers 404 for a person who is not there" do
        get "/admin/people/999999/edit"

        expect(last_response).to be_not_found
      end

      it "answers 404 when saving a person who is not there" do
        send_to("/admin/people/999999", person: { name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social" })

        expect(last_response).to be_not_found
      end
    end

    describe "removing a person" do
      let(:person) { create(:person, name: "Ada") }

      it "asks first with a form that works with scripts off" do
        get "/admin/people/#{person.id}/edit"

        expect(page).to have_css(
          "form#person-delete[method='post'][action='/admin/people/#{person.id}/delete'][data-confirm]",
        )
      end

      it "removes them and says so", :aggregate_failures do
        send_to("/admin/people/#{person.id}/delete")
        follow_redirect!

        expect(everyone).to be_empty
        expect(page).to have_css("[data-toast]", text: "Person removed")
      end

      it "answers 404 for a person who is not there" do
        send_to("/admin/people/999999/delete")

        expect(last_response).to be_not_found
      end
    end
  end

  describe "signed out" do
    let(:person) { create(:person, name: "Ada Lovelace") }

    it "sends anybody who has not signed in to sign in" do
      get "/admin/people"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "adds nobody" do
      post "/admin/people", person: { name: "Ada", key: "ada", mastodon_handle: "@ada@ruby.social" }

      expect(everyone).to be_empty
    end

    it "removes nobody" do
      post "/admin/people/#{person.id}/delete"

      expect(everyone.map(&:name)).to eq(["Ada Lovelace"])
    end
  end
end
