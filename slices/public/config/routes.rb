# frozen_string_literal: true

module Public
  class Routes < Hanami::Routes
    TAG = %r{[^/]+}

    get "/", to: "pages.index", as: :root
    get Blog::Site::WRITING, to: "posts.index", as: :writing
    get "#{Blog::Site::WRITING}.atom", to: "posts.feed", as: :writing_feed
    get "#{Blog::Site::WRITING}/tags/:tag.atom", to: "tags.feed", as: :tag_feed, tag: TAG
    get "#{Blog::Site::WRITING}/tags/:tag", to: "tags.show", as: :tag, tag: TAG
    get "#{Blog::Site::WRITING}/:slug", to: "posts.show", as: :post
    get "/about", to: "pages.about", as: :about
    get "/projects", to: "pages.projects", as: :projects
    get "/contact", to: "pages.contact", as: :contact
    post "/contact", to: "messages.create", as: :message
    post "/pulse", to: "visits.create", as: :visit
    post "/webmention", to: "webmentions.create", as: :webmention
  end
end
