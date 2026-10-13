# frozen_string_literal: true

module Issues
  GITHUB_URL = %r{\Ahttps://github\.com/(?<repo>[^/]+/[^/]+)/issues/(?<number>\d+)\z}
  LINEAR_URL = %r{\Ahttps://linear\.app/(?<workspace>[^/]+)/issue/(?<team>[^/]+)-\d+(?:/|\z)}
end
