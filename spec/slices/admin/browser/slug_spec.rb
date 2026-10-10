# frozen_string_literal: true

RSpec.describe "Admin slug preview", type: :feature do
  let(:slugs) { YAML.load_file(Hanami.app.root.join("spec/fixtures/slugs.yml")) }

  before do
    sign_in_to_admin
    visit "/admin/posts/new"
  end

  def previewed(titles)
    evaluate_script(<<~JS, titles)
      ((titles) => {
        const title = document.querySelector("[data-editor-title]");
        const path = document.querySelector("[data-editor-path]");
        return titles.map((text) => {
          title.value = text;
          title.dispatchEvent(new Event("input"));
          return path.textContent.slice(path.dataset.editorPath.length);
        });
      })(arguments[0])
    JS
  end

  it "slugs each title the way the server does" do
    expect(previewed(slugs.keys)).to eq(slugs.values)
  end

  it "matches the fixture on the server" do
    expect(slugs.keys.map { Blog::Types::Normalized::Slug[it] }).to eq(slugs.values)
  end
end
