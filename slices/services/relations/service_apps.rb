# frozen_string_literal: true

module Services
  module Relations
    class ServiceApps < Blog::DB::Relation
      schema :service_apps, infer: true
    end
  end
end
