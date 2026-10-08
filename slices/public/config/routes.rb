# frozen_string_literal: true

module Public
  class Routes < Hanami::Routes
    TAG = %r{[^/]+}
    WRITING = Hanami.app.settings.writing_path

    get "/", to: "pages.index", as: :root
    get WRITING, to: "posts.index", as: :writing
    get "#{WRITING}.atom", to: "posts.feed", as: :writing_feed
    get "#{WRITING}/tags/:tag.atom", to: "tags.feed", as: :tag_feed, tag: TAG
    get "#{WRITING}/tags/:tag", to: "tags.show", as: :tag, tag: TAG
    get "#{WRITING}/:slug", to: "posts.show", as: :post
    get "/about", to: "pages.about", as: :about
    get "/projects", to: "pages.projects", as: :projects
    get "/contact", to: "pages.contact", as: :contact
    get "/privacy", to: "pages.privacy", as: :privacy
    get "/media/:key", to: "media.show", as: :media
    get "/site.webmanifest", to: "manifests.show", as: :manifest
    post "/contact", to: "messages.create", as: :message
    post "/pulse", to: "visits.create", as: :visit
    post "/webmention", to: "webmentions.create", as: :webmention
  end
end
