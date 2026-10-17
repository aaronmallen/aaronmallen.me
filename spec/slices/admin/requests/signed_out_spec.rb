# frozen_string_literal: true

RSpec.describe "Admin signed out", type: :request do
  def self.open
    {
      "sessions.create" => "GitHub and Google call back here to sign the owner in",
      "sessions.destroy" => "signing out needs no session",
      "sessions.new" => "the sign-in page",
      "sessions.start" => "sends the owner to GitHub or Google to sign in",
    }
  end

  def self.routes
    Admin::Slice.routes
    Admin::Routes.definitions.filter_map do |verb, (path), kwargs, _|
      [verb, path, kwargs] if kwargs[:to] && !verb.start_with?("redirect") && !open.key?(kwargs[:to])
    end
  end

  def self.sample(constraint)
    ["1", "github", constraint.source.split("|").first.delete("\\")].find { /\A(?:#{constraint})\z/.match?(it) } ||
      raise(ArgumentError, "no sample matches #{constraint.inspect}")
  end

  def self.url(path, kwargs)
    "/admin#{path.gsub('*path', 'nowhere').gsub(/:(\w+)/) { sample(kwargs.fetch(Regexp.last_match(1).to_sym, /\w+/)) }}"
  end

  routes.each do |verb, path, kwargs|
    it "turns away #{verb.upcase} /admin#{path} and writes nothing", :aggregate_failures do
      token = admin_csrf_token
      sql = counting { public_send(verb, self.class.url(path, kwargs), _csrf_token: token) }

      turned_away = last_response.status == 401 || last_response.location.to_s.end_with?("/admin/sign-in")

      expect(turned_away).to be(true), "answered #{last_response.status} #{last_response.location}"
      expect(sql.grep(/\b(INSERT|UPDATE|DELETE)\b/i)).to be_empty
    end
  end

  def opened
    root = Admin::Slice.root.join("actions")
    names = Dir[root.join("**", "*.rb")].map { it.delete_prefix("#{root}/").delete_suffix(".rb").tr("/", ".") }

    names.select { Admin::Slice.key?("actions.#{it}") }.reject { Admin::Slice["actions.#{it}"].send(:sign_in_required?) }
  end

  it "lets only the routes it names skip sign-in" do
    expect(opened).to match_array(self.class.open.keys)
  end
end
