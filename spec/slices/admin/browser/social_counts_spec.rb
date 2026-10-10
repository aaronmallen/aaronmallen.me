# frozen_string_literal: true

RSpec.describe "Admin social counts", type: :feature do
  let(:samples) { YAML.load_file(Hanami.app.root.join("spec/fixtures/social_counts.yml")) }

  before do
    create(:person, key: "ada", mastodon_handle: "@ada@ruby.social", bluesky_handle: "ada.example",
                    bluesky_did: "did:plc:ada")
  end

  def counted(texts)
    evaluate_script(<<~JS, texts)
      ((texts) => {
        const body = document.querySelector("[data-social-body]");
        return texts.map((text) => {
          body.value = text;
          body.dispatchEvent(new Event("input", { bubbles: true }));
          const counts = [...document.querySelectorAll("[data-social-count]")].map((counter) => [
            counter.dataset.socialCount,
            Number(counter.querySelector("[data-social-count-text]").textContent.match(/\\d+/)[0]),
          ]);
          return Object.fromEntries(counts);
        });
      })(arguments[0])
    JS
  end

  def measured(texts)
    Admin::Slice["operations.count_network_lengths"].call(texts).map { |counts| counts.transform_values(&:count) }
  end

  it "counts each sample the way the server does" do
    connect_social_networks
    sign_in_to_admin
    visit "/admin/social"

    expect(counted(samples.keys)).to eq(samples.values)
  end

  it "matches the fixture on the server" do
    expect(measured(samples.keys)).to eq(samples.values)
  end
end
