# frozen_string_literal: true

RSpec.describe "Admin mail compose", type: :feature do
  let(:gmail) { Spec::GoogleAccounts::GMAIL }
  let(:work) { create(:mail_account, name: "aaron@work.example", address: "aaron@work.example") }
  let(:surface) { find("#mail-compose .mail-editor-surface") }

  let(:tags) do
    {
      "Bold" => "b", "Italic" => "i", "Underline" => "u", "Strikethrough" => "strike", "Bulleted list" => "ul",
      "Numbered list" => "ol", "Quote" => "blockquote", "Code" => "code",
    }
  end
  let(:keys) do
    {
      [:control, "b"] => "b", [:control, "i"] => "i", [:control, "u"] => "u", [:control, :shift, "x"] => "strike",
      [:control, :shift, "8"] => "ul", [:control, :shift, "7"] => "ol", [:control, :shift, "9"] => "blockquote",
      [:control, "e"] => "code",
    }
  end

  def add_link(url)
    fill_in "Link URL", with: url
    yield
  end

  def address
    fill_in "to", with: "ada@example.com"
    fill_in "subject", with: "Engines"
  end

  def bold_word
    write("word")
    tool("Bold").click
    select_all
  end

  def html = find("#mail-compose input[name='mail[html]']", visible: :all).value

  def open_compose
    visit "/admin/mail"
    click_link "Compose"
    surface.click
  end

  def select_all
    execute_script(<<~JS, surface)
      const range = document.createRange();
      range.selectNodeContents(arguments[0]);
      getSelection().removeAllRanges();
      getSelection().addRange(range);
    JS
  end

  def stub_drafts
    draft = google_health_json({ id: "r1", message: { id: "d1", threadId: "t5" } })
    stub_request(:post, "#{gmail}/drafts").to_return(draft)
    stub_request(:put, "#{gmail}/drafts/r1").to_return(draft)
    stub_gmail_thread("t5", [gmail_message("d1", labels: %w[DRAFT])])
  end

  def stub_send
    stub_request(:post, "#{gmail}/messages/send").to_return(google_health_json({ id: "s1", threadId: "t9" }))
    stub_gmail_thread("t9", [gmail_message("s1", labels: %w[SENT])])
  end

  def tool(name) = find("#mail-compose [role=toolbar] button[aria-label='#{name}']")

  def write(text)
    execute_script("arguments[0].innerHTML = ''", surface)
    surface.send_keys(text)
    select_all
  end

  before do
    connect_google(account_id: work.address, scopes: [*Spec::GoogleAccounts::GMAIL_SCOPES,
                                                      "https://www.googleapis.com/auth/gmail.send"])
    stub_drafts
    sign_in_to_admin
    open_compose
  end

  it "formats the selection with each toolbar button", :aggregate_failures do
    tags.each do |name, tag|
      write("word")
      tool(name).click

      expect(html).to include("<#{tag}"), "#{name} gave #{html}"
    end
  end

  it "formats the selection with each key", :aggregate_failures do
    keys.each do |pressed, tag|
      write("word")
      surface.send_keys(pressed)

      expect(html).to include("<#{tag}"), "#{pressed.inspect} gave #{html}"
    end
  end

  it "shows a pressed button for the formatting under the cursor" do
    write("word")
    tool("Bold").click

    expect(tool("Bold")["aria-pressed"]).to eq("true")
  end

  it "clears formatting from the button" do
    bold_word
    tool("Clear formatting").click

    expect(html).not_to include("<b>")
  end

  it "clears formatting from the key" do
    bold_word
    surface.send_keys([:control, "\\"])

    expect(html).not_to include("<b>")
  end

  it "links the selection from the button" do
    write("word")
    tool("Link").click
    add_link("example.com") { click_button "Add link" }

    expect(html).to include('<a href="https://example.com">word</a>')
  end

  it "links the selection from the key, and an address as mail" do
    write("word")
    surface.send_keys([:control, "k"])
    add_link("ada@example.com") { find_field("Link URL").send_keys(:enter) }

    expect(html).to include('<a href="mailto:ada@example.com">word</a>')
  end

  it "drops script and every attribute but a link's href from pasted HTML", :aggregate_failures do
    execute_script(<<~JS, surface)
      const data = new DataTransfer();
      data.setData("text/html", '<p onclick="x()" style="color:red">Hi<script>alert(1)</script>' +
        '<a href="https://a.example" class="c">a</a><a href="javascript:alert(1)">b</a></p>');
      arguments[0].dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }));
    JS

    expect(html).to include('<a href="https://a.example">a</a>')
    expect(html).not_to match(/script|onclick|style|class|javascript/)
  end

  it "shows Cc and Bcc on demand", :aggregate_failures do
    expect(page).to have_no_field("mail-compose-cc")

    click_button "cc"

    expect(page).to have_field("mail-compose-cc")
  end

  it "saves a draft to Gmail once I stop typing", :aggregate_failures do
    address

    expect(page).to have_css(".mail-compose-hint", text: /draft saved \d/)
    expect(find("#mail-compose input[name='mail[draft]']", visible: :all).value).to eq("r1")
  end

  describe "when the draft route answers a 500" do
    before do
      request_gate.refuse("/admin/mail/draft", 500)
      address
    end

    it "says the draft did not save" do
      expect(page).to have_css(".mail-compose-hint", text: "draft not saved")
    end

    it "shows the saved time again once a save goes through" do
      find(".mail-compose-hint", text: "draft not saved")
      request_gate.admit("/admin/mail/draft")
      fill_in "subject", with: "Engines, again"

      expect(page).to have_css(".mail-compose-hint", text: /draft saved \d/)
    end
  end

  it "says the draft did not save when the request gets no answer" do
    execute_script("window.fetch = () => Promise.reject(new TypeError('offline'))")
    address

    expect(page).to have_css(".mail-compose-hint", text: "draft not saved")
  end

  it "names the files I attach" do
    attach_file "mail-compose-files", __FILE__, make_visible: true

    expect(page).to have_css(".mail-attach-names", text: File.basename(__FILE__))
  end

  it "sends on Ctrl+Enter" do
    stub_send
    address
    surface.click
    surface.send_keys("Hello", %i[control enter])

    expect(page).to have_css(".toast", text: "Sent")
  end

  describe "resuming a draft" do
    def drafts = %r{\A#{gmail}/drafts\?}

    def live_update
      click_button "Discard"
      Timeout.timeout(5) { sleep 0.05 until request_gate.answered("/admin/events") >= 1 }
      find("#thread-#{create(:message, subject: 'Hello there').id}")
    end

    before do
      thread = create(:message, mail_account_id: work.id, gmail_id: "t5", subject: "Plans", visitor_hash: nil)
      Mail::Slice["relations.mail_threads"].where(id: thread.id).update(draft: true)
      stub_request(:get, drafts)
        .to_return(google_health_json({ drafts: [{ id: "r1", message: { id: "d1", threadId: "t5" } }] }))
      message = gmail_message("d1", labels: %w[DRAFT], To: "ada@example.com")
      stub_request(:get, %r{\A#{gmail}/drafts/r1\?}).to_return(google_health_json({ id: "r1", message: }))
      request_gate.reset
      visit "/admin/mail?thread=#{thread.id}&resume=1"
    end

    it "drops resume from the URL once the form draws", :aggregate_failures do
      expect(page).to have_field("to", with: "ada@example.com")
      expect(URI(current_url).query).not_to include("resume")
    end

    it "asks Gmail for the draft no more on a live update" do
      live_update

      expect(a_request(:get, drafts)).to have_been_made.once
    end
  end
end
