# frozen_string_literal: true

RSpec.describe "Code blocks", type: :feature do
  let(:markdown) do
    <<~MARKDOWN
      ```ruby
      require "types"
      # app/actions/users/create.rb
      class Create < Base
        def call = Types::String.constructor { |value| value&.downcase&.strip }
        NAME = "create"
      end
      ```
    MARKDOWN
  end
  let(:captioned) do
    <<~MARKDOWN
      ```ruby config/providers/redis.rb
      Hanami.app.register_provider(:redis) do
      end
      ```

      ```ruby
      NAME = "create"
      ```
    MARKDOWN
  end
  let(:body) { markdown }

  def bordered
    evaluate_script(<<~JS)
      [...document.querySelectorAll("pre.syntax-highlighting *")]
        .filter((node) => ["Top", "Right", "Bottom", "Left"].some((side) => getComputedStyle(node)[`border${side}Width`] !== "0px"))
        .length
    JS
  end

  def colors
    evaluate_script(<<~JS)
      Object.fromEntries(
        [".hl-keyword", ".hl-string", ".hl-entity.hl-name.hl-class", ".hl-entity.hl-name.hl-function", ".hl-comment"]
          .map((selector) => [selector, getComputedStyle(document.querySelector(`pre ${selector}`)).color])
      )
    JS
  end

  def line_tops
    evaluate_script(<<~JS, find("pre.syntax-highlighting code"))
      ((code) => {
        const range = document.createRange();
        range.selectNodeContents(code);
        return new Set([...range.getClientRects()].filter((rect) => rect.width > 0).map((rect) => Math.round(rect.top))).size;
      })(arguments[0])
    JS
  end

  def rgb(hex) = "rgb(#{hex.scan(/\h\h/).map(&:hex).join(', ')})"

  def unprefixed
    evaluate_script(<<~JS)
      [...document.querySelectorAll("pre.syntax-highlighting [class]")]
        .flatMap((node) => [...node.classList])
        .filter((name) => !name.startsWith("hl-"))
    JS
  end

  shared_examples "rendered code" do
    it "prefixes every highlighter class" do
      expect(unprefixed).to be_empty
    end

    it "renders each source line as one line" do
      expect(line_tops).to eq(markdown.lines.size - 2)
    end

    it "draws no border inside the block" do
      expect(bordered).to eq(0)
    end

    {
      "light" => %w[#b3105a #735808 #3a5f0e #0f6f85 #696658],
      "dark" => %w[#fb5a94 #e6db74 #a6e22e #66d9ef #939081],
    }.each do |scheme, hexes|
      it "colors keywords, strings, classes, functions and comments in #{scheme} mode" do
        emulate_color_scheme(scheme)

        expect(colors.values).to eq(hexes.map { rgb(it) })
      end
    end
  end

  shared_examples "file caption" do
    it "captions the fence that names its file" do
      expect(page).to have_css(".cf > .cf-n", exact_text: "config/providers/redis.rb")
    end

    it "marks the caption with a file icon" do
      expect(page).to have_css(".cf-n > i.fa-regular.fa-file-code[aria-hidden='true']")
    end

    it "keeps the highlighted code under the caption" do
      expect(page).to have_css(".cf > .cf-n + pre.syntax-highlighting .hl-keyword", text: "do")
    end

    it "leaves the fence without a file bare" do
      expect(page).to have_css("pre.syntax-highlighting:not(.cf pre)", count: 1)
    end
  end

  describe "on the public post page" do
    before do
      create(:post, :published, slug: "hello", body:)
      visit "/writing/hello"
    end

    it_behaves_like "rendered code"

    context "with a file name" do
      let(:body) { captioned }

      it_behaves_like "file caption"
    end
  end

  describe "in the admin preview" do
    before do
      sign_in_to_admin
      visit "/admin/posts/new"
      fill_in "Body", with: body
      find(".edit .seg-option", text: "Preview").click
      page.assert_selector(".preview pre.syntax-highlighting")
    end

    it_behaves_like "rendered code"

    context "with a file name" do
      let(:body) { captioned }

      it_behaves_like "file caption"
    end
  end
end
