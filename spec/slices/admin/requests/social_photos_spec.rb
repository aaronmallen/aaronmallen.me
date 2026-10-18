# frozen_string_literal: true

RSpec.describe "Admin social post photos", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:photos) { Array.new(5) { create(:photo) } }

  def alts = page.all("[data-social-part] [data-social-photo-alt]").map(&:value)

  def compose(parts: %w[one], photos: [], intent: "draft")
    social = { accounts: ["", social_account("mastodon").id.to_s], parts:, photos: ["", *photos] }
    post "/admin/social", _csrf_token: admin_csrf_token, intent:, social:
  end

  def held = Social::Slice["relations.social_post_photos"].in_order.to_a.map { it.values_at(:photo_key, :alt_text) }

  def message(code) = Admin::Slice["i18n"].t(code, scope: "ui.components.social.field_error.photos")

  def photo(index, part: 1, alt: "") = { part: part.to_s, key: photos[index].key, alt: }

  def update(social_post, photos:)
    social = { accounts: ["", social_account("mastodon").id.to_s], parts: %w[one], photos: ["", *photos] }
    post "/admin/social/#{social_post.id}", _csrf_token: admin_csrf_token, intent: "draft", social:
  end

  before do
    connect_social_networks
    sign_in_to_admin
  end

  describe "the composer" do
    it "offers a photo picker on each part with a store", :aggregate_failures do
      connect_media_store
      get "/admin/social"

      expect(page).to have_css("[data-social-part] [data-social-photo-pick]", count: 1)
      expect(page).to have_css("[data-social-part] [data-social-photos][data-social-upload='/admin/photos']")
    end

    it "offers no photo picker without a store" do
      get "/admin/social"

      expect(page).to have_no_css("[data-social-photo-pick]")
    end
  end

  describe "saving" do
    it "keeps each photo in order with its alt text" do
      compose(photos: [photo(1, alt: "A dog"), photo(0, alt: "A cat")])

      expect(held).to eq([[photos[1].key, "A dog"], [photos[0].key, "A cat"]])
    end

    it "keeps a photo with no alt text" do
      compose(photos: [photo(0)])

      expect(held).to eq([[photos[0].key, nil]])
    end

    it "puts each photo on the part that holds it, past a blank part" do
      compose(parts: ["one", "", "three"], photos: [photo(0, part: 3)])
      part = social_posts_in("drafts").first.parts.last

      expect(Social::Slice["relations.social_post_photos"].first[:social_post_part_id]).to eq(part.id)
    end

    it "drops every photo the form no longer lists" do
      compose(photos: [photo(0)])
      update(social_posts_in("drafts").first, photos: [])

      expect(held).to eq([])
    end
  end

  describe "a post it won't take" do
    it "refuses a fifth photo on a part and says why", :aggregate_failures do
      compose(photos: Array.new(5) { photo(it) })

      expect(last_response.status).to eq(422)
      expect(page).to have_css(".field-error", text: message("many"))
    end

    it "keeps the photos and their alt text in the form", :aggregate_failures do
      compose(photos: Array.new(5) { photo(it, alt: "Photo #{it}") })

      expect(alts).to eq(Array.new(5) { "Photo #{it}" })
      expect(held).to eq([])
    end

    it "refuses the same photo twice in a part" do
      compose(photos: [photo(0), photo(0)])

      expect(page).to have_css(".field-error", text: message("duplicate"))
    end

    it "refuses photos on a blank part" do
      compose(parts: ["one", ""], photos: [photo(0, part: 2)])

      expect(page).to have_css(".field-error", text: message("silent_part"))
    end
  end

  describe "editing" do
    let(:social_post) do
      compose(photos: [photo(0, alt: "A cat"), photo(1)])
      social_posts_in("drafts").first
    end

    before do
      connect_media_store
      get "/admin/social", edit: social_post.id
    end

    it "shows each photo in order with its alt text", :aggregate_failures do
      expect(page.all("[data-social-part] [data-social-photo-key]", visible: :all).map(&:value))
        .to eq(photos.first(2).map(&:key))
      expect(alts).to eq(["A cat", ""])
    end

    it "shows the photos in the preview" do
      expect(page.all(".compose-preview-photo").map { it[:alt] }).to eq(["A cat", ""])
    end

    it "counts the photos on the part" do
      expect(page).to have_css("[data-social-photo-count]", text: "Photos 2/4")
    end
  end

  describe "editing a thread" do
    it "shows a photo on the part that holds it" do
      compose(parts: %w[one two], photos: [photo(2, part: 2)])
      connect_media_store
      get "/admin/social", edit: social_posts_in("drafts").first.id

      expect(page.all("[data-social-part]").map { it.all("[data-social-photo-key]", visible: :all).map(&:value) })
        .to eq([[], [photos[2].key]])
    end
  end

  describe "the queue" do
    def kept(index, part: 1, alt: nil) = { part:, key: photos[index].key, alt: }

    def queue_photos = page.all(".sq-photo").map { [it[:src], it[:alt]] }

    def save(status, photos: nil, at: Time.now + 3600)
      Social::Slice["repos.social_post_mutations"]
        .create_with_parts(parts: %w[one two], photos:, targets: %w[mastodon], status:, posted_at: at)
    end

    def src(index) = Blog::Helpers::MediaPath.for(photos[index].key)

    {
      "queued" => %w[scheduled queued],
      "draft" => %w[draft drafts],
      "posted" => %w[posted posted],
    }.each do |name, (status, filter)|
      it "shows a #{name} post's photos under each part in order with their alt text" do
        save(status, photos: [kept(2, part: 2, alt: "A bird"), kept(1, alt: "A dog"), kept(0, alt: "A cat")])
        get("/admin/social", filter:)

        expect(queue_photos).to eq([[src(1), "A dog"], [src(0), "A cat"], [src(2), "A bird"]])
      end
    end

    it "puts each photo under its own part" do
      save("scheduled", photos: [kept(0, part: 2, alt: "A cat")])
      get "/admin/social"

      expect(page).to have_css(".sq-part + .sq-part + .sq-photos .sq-photo[alt='A cat']")
    end

    it "shows no photos for a post without any", :aggregate_failures do
      save("scheduled")
      get "/admin/social"

      expect(page).to have_css(".sq-part", count: 2)
      expect(page).to have_no_css(".sq-photos")
    end
  end
end
