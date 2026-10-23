Feature: Webmention settings
  The webmentions tab of Settings holds the switches, the hosts that are one
  person's site, each post's webmention state and the trusted authors.

  Background:
    Given I am signed in to the admin

  Scenario: The webmentions tab heads Settings, fills its tab alone and passes axe
    When I visit "/admin/settings/webmentions"
    Then the webmentions page is headed "Settings"
    And the webmentions screen tab "webmentions" is current
    And the webmention page has the element "#webmentions #webmention-settings"
    And the webmention page has no element "#people"
    And I see "Per post"
    And the webmention page has no element "a.pill-nav-link[aria-current]"
    And the webmention page has no element "#command-palette-webmentions .pal-r-sub"
    And I see "Endpoint: POST /webmention"
    And the page has no axe breaches in light or dark

  Scenario Outline: Turning "<label>" off saves it without a button
    When I visit "/admin/settings/webmentions"
    Then the webmention settings switch "<label>" is on
    When I turn off the webmention switch "<label>"
    Then I see "Settings saved"
    And the webmention_settings table has a row with:
      | <column> |
      | false    |

    Examples:
      | label                                          | column                     |
      | Receive webmentions                            | receive                    |
      | Send webmentions on publish                    | send_on_publish            |
      | Auto-approve known authors                     | auto_approve_known_authors |
      | Auto-approve likes                             | auto_approve_likes         |
      | Auto-approve reposts                           | auto_approve_reposts       |
      | Enable on new posts by default                 | enable_on_new_posts        |
      | Accept Mastodon + Bluesky replies from Bridgy  | accept_bridgy              |

  Scenario Outline: "<label>" shows as off once it is off
    Given the webmention setting <column> is off
    When I visit "/admin/settings/webmentions"
    Then the webmention settings switch "<label>" is off

    Examples:
      | label                                          | column                     |
      | Receive webmentions                            | receive                    |
      | Send webmentions on publish                    | send_on_publish            |
      | Auto-approve known authors                     | auto_approve_known_authors |
      | Auto-approve likes                             | auto_approve_likes         |
      | Auto-approve reposts                           | auto_approve_reposts       |
      | Enable on new posts by default                 | enable_on_new_posts        |
      | Accept Mastodon + Bluesky replies from Bridgy  | accept_bridgy              |

  Scenario: A save leaves the settings it is not sent alone and returns to the webmentions tab
    Given the webmention single-author hosts are "ada.example"
    When I visit "/admin/settings/webmentions"
    And I post to the admin "/admin/webmentions/settings" with:
      | settings[receive] | 0 |
    Then I am on "/admin/settings/webmentions"
    And the address ends with "#webmentions"
    And I see "Settings saved"
    And the webmention_settings table has a row with:
      | receive | send_on_publish | single_author_hosts |
      | false   | true            | {ada.example}       |

  Scenario: A save that changes nothing says so
    When I visit "/admin/settings/webmentions"
    And I save the webmention settings with the hosts:
      """
      """
    Then I see "Nothing saved · no setting changed"

  Scenario: The hosts are saved one per line, cleaned up and in order, and shown one per line
    When I visit "/admin/settings/webmentions"
    And I save the webmention settings with the hosts:
      """
      grace.example
      https://Ada.Example/about

      not a host/
      """
    Then the webmention_settings table has a row with:
      | single_author_hosts         |
      | {ada.example,grace.example} |
    When I visit "/admin/settings/webmentions"
    Then the webmention hosts read "ada.example\ngrace.example"

  Scenario: Hosts sent empty are cleared, and the same hosts again change nothing
    Given the webmention single-author hosts are "ada.example"
    When I visit "/admin/settings/webmentions"
    And I save the webmention settings with the hosts:
      """
      ada.example
      """
    Then I see "Nothing saved · no setting changed"
    When I save the webmention settings with the hosts:
      """
      """
    Then the webmention_settings table has a row with:
      | single_author_hosts |
      | {}                  |

  Scenario: An author at a site's root is approved from any page only once the host is listed
    Given a published post "Hello" taking webmentions
    And these webmentions on the post "Hello":
      | author_name | author_url          |
      | Ada         | http://203.0.113.7/ |
    And the source page "http://203.0.113.7/notes/1" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.7/">Ada</a><a href="{post}">read</a></div>
      """
    And the source page "http://203.0.113.7/notes/2" reads:
      """
      <div class="h-entry"><a class="p-author h-card" href="http://203.0.113.7/">Ada</a><a href="{post}">read</a></div>
      """
    When I visit "/admin/webmentions"
    And I press "Approve" on the webmention from "Ada"
    And the webmention check runs for "http://203.0.113.7/notes/1"
    Then the webmention from "http://203.0.113.7/notes/1" has:
      | status  |
      | pending |
    When I visit "/admin/settings/webmentions"
    Then I see "Each is one person's site, so an author at its root covers every page on it."
    When I save the webmention settings with the hosts:
      """
      203.0.113.7
      """
    And the webmention check runs for "http://203.0.113.7/notes/2"
    Then the webmention from "http://203.0.113.7/notes/2" has:
      | status   |
      | approved |

  Scenario: The per post card shows each post's state, newest first, linked to its editor
    Given the posts table holds:
      | title | status    | published_at         | webmentions_enabled |
      | Older | published | 2026-09-01T12:00:00Z | true                |
      | Newer | published | 2026-09-02T12:00:00Z | false               |
    When I visit "/admin/settings/webmentions"
    Then the per post card lists "Newer, Older"
    And the per post card reads "Older" as "on"
    And the per post card reads "Newer" as "off"
    And I see the link "Older" to "/admin/posts/1/edit"

  Scenario: The per post card and the trusted authors card say when they are empty
    When I visit "/admin/settings/webmentions"
    Then I see "No posts yet."
    And I see "No trusted authors yet."

  Scenario: The trusted authors card lists the newest first, with no field to add one
    Given the trusted author "https://ada.example/" added "1 minute ago"
    And the trusted author "https://grace.example/" added "now"
    When I visit "/admin/settings/webmentions"
    Then the trusted authors read "https://grace.example/, https://ada.example/"
    And the webmention page has no element "#trusted-authors input:not([type='hidden'])"

  Scenario: Removing a trusted author keeps their approved webmentions up
    Given a published post "Hello" taking webmentions
    And the trusted author "https://ada.example/"
    And these webmentions on the post "Hello":
      | author_name | author_url           | status   |
      | Ada         | https://ada.example/ | approved |
    When I visit "/admin/settings/webmentions"
    And I remove the trusted author "https://ada.example/"
    Then I see "Removed · their next reply or mention waits for review"
    And the address ends with "/admin/settings/webmentions#webmentions"
    And the trusted_authors table holds 0 rows
    And the webmentions table has a row with:
      | author_name | status   |
      | Ada         | approved |

  Scenario: Removing an author not on the list is not found
    When I visit "/admin/settings/webmentions"
    And I post to the admin "/admin/webmentions/trusted_authors/remove" with:
      | author_url | https://ada.example/ |
    Then the admin answers 404
