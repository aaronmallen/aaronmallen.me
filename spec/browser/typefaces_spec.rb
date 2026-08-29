# frozen_string_literal: true

RSpec.describe "Typefaces", type: :feature do
  def face(family)
    evaluate_async_script(<<~JS, family)
      const [family, done] = arguments;
      document.fonts.ready.then(() => done({
        check: document.fonts.check(`1em "${family}"`),
        loaded: [...document.fonts].some((face) => face.family.replaceAll('"', "") === family && face.status === "loaded"),
      }));
    JS
  end

  describe "on the home page" do
    before { visit "/" }

    it "draws the body in Newsreader" do
      expect(face("Newsreader")).to eq("check" => true, "loaded" => true)
    end
  end

  describe "on an admin page" do
    before do
      sign_in_to_admin
      visit "/admin/tags"
    end

    ["Bricolage Grotesque", "IBM Plex Mono"].each do |family|
      it "draws in #{family}" do
        expect(face(family)).to eq("check" => true, "loaded" => true)
      end
    end
  end
end
