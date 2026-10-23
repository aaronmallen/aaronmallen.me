Feature: Social counts refresh
  The engagement job reads the likes, replies and reposts of each social post sent in the last 30 days, and keeps
  the counts it had when a network cannot answer.

  Background:
    Given a Mastodon account on "ruby.social" is connected
    And a Bluesky account "ada.example" is connected

  Scenario: The counts come in from both networks without signing in to Bluesky
    Given the social_posts table holds:
      | targets            | status | posted_at  |
      | {mastodon,bluesky} | posted | 1 day ago  |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids                                   |
      | mastodon | 1             | {110,111}                                    |
      | bluesky  | 2             | {at://did:plc:ada/app.bsky.feed.post/3kabc} |
    And Mastodon answers GET "/ruby.social/api/v1/statuses/110" with:
      """
      {"id": "110", "favourites_count": 3, "replies_count": 2, "reblogs_count": 1}
      """
    And Bluesky's app view answers GET "/xrpc/app.bsky.feed.getPosts" with:
      """
      {"posts": [{"uri": "at://did:plc:ada/app.bsky.feed.post/3kabc", "likeCount": 9, "replyCount": 8, "repostCount": 7}]}
      """
    When the social counts refresh
    Then the social_post_deliveries table has a row with:
      | network  | like_count | reply_count | repost_count |
      | mastodon | 3          | 2           | 1            |
    And the social_post_deliveries table has a row with:
      | network | like_count | reply_count | repost_count |
      | bluesky | 9          | 8           | 7            |

  Scenario: A post sent a day short of the window refreshes
    Given the social_posts table holds:
      | targets    | status | posted_at   |
      | {mastodon} | posted | 29 days ago |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids |
      | mastodon | 1             | {110}      |
    And Mastodon answers GET "/ruby.social/api/v1/statuses/110" with:
      """
      {"id": "110", "favourites_count": 3, "replies_count": 0, "reblogs_count": 0}
      """
    When the social counts refresh
    Then the social_post_deliveries table has a row with:
      | like_count |
      | 3          |

  Scenario Outline: A post the job should not ask about is left alone
    Given the social_posts table holds:
      | targets    | status   | posted_at   |
      | {mastodon} | <status> | <posted at> |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids   | like_count |
      | mastodon | 1             | <remote ids> | 4          |
    When the social counts refresh
    And the social jobs have all run
    Then the social_post_deliveries table has a row with:
      | like_count |
      | 4          |

    Examples:
      | status    | posted at   | remote ids |
      | posted    | 31 days ago | {110}      |
      | scheduled | now         | {110}      |
      | posted    | 1 day ago   | {}         |

  Scenario: A network that lost its account keeps its counts
    Given social account 1 is disconnected
    And social account 2 is disconnected
    And the social_posts table holds:
      | targets            | status | posted_at |
      | {mastodon,bluesky} | posted | 1 day ago |
    And the social_post_deliveries table holds:
      | social_post_id | network  | remote_ids                                   | like_count |
      | 1              | mastodon | {110}                                        | 4          |
      | 1              | bluesky  | {at://did:plc:ada/app.bsky.feed.post/3kabc} | 5          |
    When the social counts refresh
    And the social jobs have all run
    Then the social_post_deliveries table has a row with:
      | network  | like_count |
      | mastodon | 4          |
    And the social_post_deliveries table has a row with:
      | network | like_count |
      | bluesky | 5          |

  Scenario Outline: Mastodon failing keeps its counts and still lets Bluesky refresh
    Given the social_posts table holds:
      | targets            | status | posted_at |
      | {mastodon,bluesky} | posted | 1 day ago |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids                                   | like_count |
      | mastodon | 1             | {110}                                        | 5          |
      | bluesky  | 2             | {at://did:plc:ada/app.bsky.feed.post/3kabc} | 6          |
    And Mastodon answers GET "/ruby.social/api/v1/statuses/110" <answer>
    And Bluesky's app view answers GET "/xrpc/app.bsky.feed.getPosts" with:
      """
      {"posts": [{"uri": "at://did:plc:ada/app.bsky.feed.post/3kabc", "likeCount": 9, "replyCount": 0, "repostCount": 0}]}
      """
    When the social counts refresh
    Then the social_post_deliveries table has a row with:
      | network | like_count |
      | bluesky | 9          |
    And the social_post_deliveries table has a row with:
      | network  | like_count | error |
      | mastodon | 5          | null  |

    Examples:
      | answer          |
      | with status 500 |
      | with status 429 |

  Scenario: Mastodon answering with a page keeps its counts
    Given the social_posts table holds:
      | targets    | status | posted_at |
      | {mastodon} | posted | 1 day ago |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids | like_count |
      | mastodon | 1             | {110}      | 5          |
    And Mastodon answers GET "/ruby.social/api/v1/statuses/110" with:
      """
      <html></html>
      """
    When the social counts refresh
    And the social jobs have all run
    Then the social_post_deliveries table has a row with:
      | like_count | error |
      | 5          | null  |

  Scenario: Bluesky failing keeps its counts
    Given the social_posts table holds:
      | targets   | status | posted_at |
      | {bluesky} | posted | 1 day ago |
    And the deliveries of social post 1 are:
      | network | connection_id | remote_ids                                   | like_count |
      | bluesky | 2             | {at://did:plc:ada/app.bsky.feed.post/3kabc} | 6          |
    And Bluesky's app view answers GET "/xrpc/app.bsky.feed.getPosts" with status 500
    When the social counts refresh
    And the social jobs have all run
    Then the social_post_deliveries table has a row with:
      | like_count |
      | 6          |

  Scenario: Bluesky no longer having the post keeps its counts
    Given the social_posts table holds:
      | targets   | status | posted_at |
      | {bluesky} | posted | 1 day ago |
    And the deliveries of social post 1 are:
      | network | connection_id | remote_ids                                   | like_count |
      | bluesky | 2             | {at://did:plc:ada/app.bsky.feed.post/3kabc} | 6          |
    And Bluesky's app view answers GET "/xrpc/app.bsky.feed.getPosts" with:
      """
      {"posts": []}
      """
    When the social counts refresh
    And the social jobs have all run
    Then the social_post_deliveries table has a row with:
      | like_count |
      | 6          |

  Scenario: A post sent from a second Mastodon account asks that account's server
    Given a Mastodon account on "hachyderm.io" is connected
    And the social_posts table holds:
      | targets    | status | posted_at |
      | {mastodon} | posted | 1 day ago |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids |
      | mastodon | 3             | {220}      |
    And Mastodon answers GET "/hachyderm.io/api/v1/statuses/220" with:
      """
      {"id": "220", "favourites_count": 6, "replies_count": 0, "reblogs_count": 0}
      """
    When the social counts refresh
    Then the social_post_deliveries table has a row with:
      | like_count |
      | 6          |

  Scenario: The posts after one that errors still refresh
    Given the social_posts table holds:
      | targets    | status | posted_at |
      | {mastodon} | posted | 2 days ago |
      | {mastodon} | posted | 1 day ago  |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids |
      | mastodon | 1             | {110}      |
    And the deliveries of social post 2 are:
      | network  | connection_id | remote_ids |
      | mastodon | 1             | {120}      |
    And Mastodon answers GET "/ruby.social/api/v1/statuses/110" with status 429
    And Mastodon answers GET "/ruby.social/api/v1/statuses/120" with:
      """
      {"id": "120", "favourites_count": 3, "replies_count": 0, "reblogs_count": 0}
      """
    When the social counts refresh
    Then the social_post_deliveries table has a row with:
      | social_post_id | like_count |
      | 2              | 3          |

  Scenario: A LinkedIn account that never granted post stats is not asked
    Given a LinkedIn account is connected
    And the social_posts table holds:
      | targets    | status | posted_at |
      | {linkedin} | posted | 1 day ago |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids        |
      | linkedin | 3             | {urn:li:share:7}  |
    When the social counts refresh
    And the social jobs have all run
    Then the social_post_deliveries table has a row with:
      | like_count |
      | 0          |

  Scenario: LinkedIn refusing the read leaves its counts blank and moves on
    Given a LinkedIn account is connected with leave to read post stats
    And the social_posts table holds:
      | targets    | status | posted_at  |
      | {linkedin} | posted | 2 days ago |
      | {mastodon} | posted | 1 day ago  |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids       |
      | linkedin | 3             | {urn:li:share:7} |
    And the deliveries of social post 2 are:
      | network  | connection_id | remote_ids |
      | mastodon | 1             | {110}      |
    And LinkedIn answers GET "/rest/memberCreatorPostAnalytics" with status 403
    And Mastodon answers GET "/ruby.social/api/v1/statuses/110" with:
      """
      {"id": "110", "favourites_count": 3, "replies_count": 0, "reblogs_count": 0}
      """
    When the social counts refresh
    Then the social_post_deliveries table has a row with:
      | network  | like_count |
      | mastodon | 3          |
    And the social_post_deliveries table has a row with:
      | network  | like_count | error |
      | linkedin | 0          | null  |

  Scenario: LinkedIn's counts come in, each asked for by its own read of the post
    Given a LinkedIn account is connected with leave to read post stats
    And the social_posts table holds:
      | targets    | status | posted_at |
      | {linkedin} | posted | 1 day ago |
    And the deliveries of social post 1 are:
      | network  | connection_id | remote_ids       |
      | linkedin | 3             | {urn:li:share:7} |
    And LinkedIn answers GET "/rest/memberCreatorPostAnalytics?q=entity&entity=(share:urn%3Ali%3Ashare%3A7)&queryType=REACTION" with:
      """
      {"elements": [{"count": 4, "metricType": "REACTION"}]}
      """
    And LinkedIn answers GET "/rest/memberCreatorPostAnalytics?q=entity&entity=(share:urn%3Ali%3Ashare%3A7)&queryType=COMMENT" with:
      """
      {"elements": [{"count": 3, "metricType": "COMMENT"}]}
      """
    And LinkedIn answers GET "/rest/memberCreatorPostAnalytics?q=entity&entity=(share:urn%3Ali%3Ashare%3A7)&queryType=RESHARE" with:
      """
      {"elements": [{"count": 2, "metricType": "RESHARE"}]}
      """
    When the social counts refresh
    Then the social_post_deliveries table has a row with:
      | network  | like_count | reply_count | repost_count |
      | linkedin | 4          | 3           | 2            |
    And LinkedIn heard 3 stats reads naming "(share:urn:li:share:7)"
