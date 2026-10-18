# frozen_string_literal: true

RSpec.describe "Admin axe coverage", type: :app do
  def self.exempt
    {
      "events.show" => "the live update stream, not HTML",
      "mail.attachment" => "sends a mail attachment to download, not HTML",
      "people.search" => "a results fragment the person search screen shows",
      "projects.choices" => "JSON for the project picker",
      "saved_views.palette" => "JSON for the command palette",
      "search.palette" => "JSON for the command palette",
      "services.index" => "redirects to the services settings tab",
      "tags.choices" => "JSON for the tag field",
      "tags.index" => "redirects to the tagging settings tab",
      "tasks.in_progress" => "JSON for the palette's running tasks",
    }
  end

  def browser_spec(name) = Hanami.app.root.join("spec/slices/admin/browser/#{name}_spec.rb").read

  def menus = browser_spec("menus").scan(/^\s+"([\w.]+)" => \[:/).flatten

  def pattern(path, kwargs)
    source = Regexp.escape(path).gsub(/\\\*\w+/, ".+").gsub(/:(\w+)/) do
      "(?:#{kwargs.fetch(Regexp.last_match(1).to_sym, %r{[^/]+}).source})"
    end
    /\A#{source}\z/
  end

  def routes
    @routes ||= begin
      Admin::Slice.routes
      Admin::Routes.definitions.filter_map do |verb, (path), kwargs, _|
        [kwargs[:to], pattern(path, kwargs)] if verb == :get
      end
    end
  end

  def visited
    paths = visited_paths.filter_map { |path| routes.find { |_, matcher| matcher.match?(path) }&.first }
    (paths + menus).uniq
  end

  def visited_paths
    browser_spec("readable").scan(%r{(?:=>|visit|tick\()\s*"/admin([^"]*)"}).map do |(path)|
      path.gsub(/#\{[^}]*\}/, "1").sub(/\?.*/, "").then { it.empty? ? "/" : it }
    end
  end

  it "finds the admin pages and the ones the browser specs check", :aggregate_failures do
    expect(routes.map(&:first)).to include("today.show", "tasks.menu", "not_found")
    expect(visited).to include("today.show", "tasks.edit", "not_found", "tasks.menu")
  end

  it "checks every admin page in the readable or menus spec or says why not" do
    unchecked = routes.map(&:first).uniq - visited - self.class.exempt.keys

    expect(unchecked).to be_empty
  end

  it "exempts only pages the browser specs miss" do
    expect(self.class.exempt.keys & visited).to be_empty
  end

  it "names only routes that exist", :aggregate_failures do
    expect(self.class.exempt.keys - routes.map(&:first)).to be_empty
    expect(menus - routes.map(&:first)).to be_empty
  end
end
