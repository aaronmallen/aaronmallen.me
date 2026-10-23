Feature: Cross-posting a post when it goes live
  The editor writes the cross-post with the post, counts it as each network will, and queues it once the post is live.

  Background:
    Given I am signed in to the admin
    And Mastodon and Bluesky are connected for cross-posts

  Scenario: A new post starts with the cross-post on and every connected network picked
    When I open a new post
    And I open the post details
    Then the post admin shows "Syndication"
    And the post admin shows "It goes out within a minute of the post first going live."
    And the post field "Queue a cross-post when this goes live" is ticked
    And the "Mastodon" network is ticked in the post details
    And the "Bluesky" network is ticked in the post details
    And the "LinkedIn" network is disabled in the post details
    And the page has no axe breaches in light or dark

  Scenario: A network with no account to post from is off
    Given Bluesky is not connected for cross-posts
    When I open a new post
    Then the "Bluesky" network is disabled in the post details

  Scenario: The cross-post starts as the title and the post's link, counted per network
    Given I wrote a draft post "Hello"
    When I open the editor for "Hello"
    Then the cross-post text of the editor is the title and link of "hello"
    And the cross-post counts read "Mastodon 30/500, Bluesky 55/300, LinkedIn 56/3000"

  Scenario: The editor keeps the cross-post text saved with the post and the networks it picked
    Given I wrote a draft post "Hello" with:
      | syndication_body    | In my own words |
      | syndication_enabled | true            |
      | syndication_targets | {bluesky}       |
    When I open the editor for "Hello"
    Then the post field "Cross-post text" holds "In my own words"
    And the post field "Queue a cross-post when this goes live" is ticked
    And the "Bluesky" network is ticked in the post details
    And the "Mastodon" network is unticked in the post details

  Scenario: The editor counts a mention as each network gets it
    Given the people table holds:
      | key | name         | mastodon_handle   | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social  | ada.bsky.social | did:plc:ada |
    And I wrote a draft post "Hello" with:
      | syndication_body | hi @{ada} |
    When I open the editor for "Hello"
    Then the cross-post counts read "Mastodon 7/500, Bluesky 19/300, LinkedIn 15/3000"

  Scenario: Text over Bluesky's limit once its link is tagged reads as over
    Given I wrote a draft post "Hello" with:
      | syndication_body    | {262 a} |
      | syndication_targets | {bluesky} |
    And the cross-post of "Hello" ends with its link
    When I open the editor for "Hello"
    Then the cross-post count for Bluesky is over

  Scenario: Saving keeps the cross-post, and a failed save keeps what was typed
    When I open a new post
    And I fill in the post details "Cross-post text" with "In my own words"
    And I press the post button "Save draft"
    Then the post field "Cross-post text" holds "In my own words"
    And the post field "Queue a cross-post when this goes live" is ticked
    When I fill in the post "Title" with "Hello"
    And I press the post button "Save draft"
    Then the posts table has a row with:
      | title | syndication_enabled | syndication_body | syndication_targets |
      | Hello | true                | In my own words  | {mastodon,bluesky}  |

  Scenario: Turning every network off clears them and queues nothing
    Given I wrote a draft post "Hello" with:
      | syndication_enabled | true               |
      | syndication_targets | {mastodon,bluesky} |
    When I open the editor for "Hello"
    And I pick the "Mastodon" network in the post details
    And I pick the "Bluesky" network in the post details
    And I press the post button "Publish"
    Then the posts table has a row with:
      | title | status    | syndication_targets |
      | Hello | published | {}                  |
    And no cross-post waits to go out after 1 syndication run

  Scenario: Publishing queues the cross-post for the moment the post goes live
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Cross-post text" with "In my own words"
    And I press the post button "Publish"
    Then the queued cross-post for "Hello" reads "In my own words" to "{mastodon,bluesky}"
    And the cross-post for "Hello" went out at its publish time

  Scenario Outline: Nothing is queued for a draft, a scheduled post or with the cross-post off
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Cross-post text" with "In my own words"
    And I fill in the post details "Publish time (Chicago)" with "<publish at>"
    And I turn <switch> "Queue a cross-post when this goes live" in the post details
    And I press the post button "<button>"
    Then the posts table holds 1 rows
    And no cross-post waits to go out after <runs> syndication runs

    Examples:
      | publish at       | switch | button     | runs |
      |                  | on     | Save draft | 0    |
      | 2030-09-07T10:30 | on     | Schedule   | 0    |
      |                  | off    | Publish    | 1    |

  Scenario: Saving a published post again queues nothing more
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Cross-post text" with "In my own words"
    And I press the post button "Publish"
    Then 1 cross-post waits to go out for "Hello"
    When I save the post
    Then the post toast says "Saved"
    And 1 cross-post waits to go out for "Hello"

  Scenario: Turning the cross-post on after publishing queues it once
    Given I wrote a published post "Hello"
    When I open the editor for "Hello"
    And I fill in the post details "Cross-post text" with "In my own words"
    And I turn on "Queue a cross-post when this goes live" in the post details
    And I pick the "Mastodon" network in the post details
    And I pick the "Bluesky" network in the post details
    And I save the post
    Then the queued cross-post for "Hello" reads "In my own words" to "{mastodon,bluesky}"

  Scenario: A post that has cross-posted queues nothing new and saves text over the limit
    Given I wrote a published post "Hello"
    And the post "Hello" has a social post posted
    When I open the editor for "Hello"
    And I fill in the post details "Cross-post text" with "{301 a}"
    And I turn on "Queue a cross-post when this goes live" in the post details
    And I save the post
    Then the post toast says "Saved"
    And 0 cross-posts wait to go out for "Hello"
    And the posts table has a row with:
      | title | syndication_enabled |
      | Hello | true                |

  Scenario: Turning the cross-post on after publishing refuses text over a network's limit
    Given I wrote a published post "Hello"
    When I open the editor for "Hello"
    And I fill in the post details "Cross-post text" with "{301 a}"
    And I turn on "Queue a cross-post when this goes live" in the post details
    And I pick the "Mastodon" network in the post details
    And I pick the "Bluesky" network in the post details
    And I save the post
    Then the post field error reads "The cross-post is over the limit for a network you picked."
    And the posts table has a row with:
      | title | syndication_enabled |
      | Hello | false               |

  Scenario Outline: Publishing refuses a cross-post that will not fit
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada.bsky.social | did:plc:ada |
    When I open a new post
    And I fill in the post "Title" with "<title>"
    And I fill in the post details "Slug" with "hello"
    And I fill in the post details "Cross-post text" with "<text>"
    And I pick the "<off>" network in the post details
    And I press the post button "Publish"
    Then the post field error reads "<error>"
    And the posts table holds 0 rows

    Examples:
      | title   | text           | off      | error                                                                       |
      | Hello   | {301 a}        | none     | The cross-post is over the limit for a network you picked.                  |
      | Hello   | {262 a} {link} | Mastodon | The cross-post is over the limit for a network you picked.                  |
      | {262 a} |                | Mastodon | The title and link that go out are over the limit for a network you picked. |
      | {301 a} |                | none     | The title and link that go out are over the limit for a network you picked. |
      | Hello   | {290 a} @{ada} | Mastodon | The cross-post is over the limit for a network you picked.                  |

  Scenario: A title and link that fit Bluesky once the link is tagged publish
    When I open a new post
    And I fill in the post "Title" with "{250 a}"
    And I fill in the post details "Slug" with "hello"
    And I pick the "Mastodon" network in the post details
    And I press the post button "Publish"
    Then the posts table has a row with:
      | slug  | status    |
      | hello | published |

  Scenario: A title that gives no slug shows the blank slug error
    When I open a new post
    And I fill in the post "Title" with "日本語"
    And I press the post button "Publish"
    Then the post field error reads "Add a slug with a letter or number in it."
    And the posts table holds 0 rows

  Scenario: A mention of nobody in the directory is refused
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Cross-post text" with "hi @{grace}"
    And I press the post button "Save draft"
    Then the post field error reads "A mention names nobody in the directory."

  Scenario: A cross-post that fits once its mention expands is queued expanded
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada.bsky.social | did:plc:ada |
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Cross-post text" with "{280 a} @{ada}"
    And I pick the "Mastodon" network in the post details
    And I press the post button "Publish"
    Then the posts table has a row with:
      | title | status    |
      | Hello | published |
    And 1 cross-post waits to go out for "Hello"

  Scenario: A cross-post that fits once its mention expands goes out to Bluesky expanded
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada.bsky.social | did:plc:ada |
    And Bluesky answers POST "/xrpc/com.atproto.server.createSession" with:
      """
      {"accessJwt": "jwt", "did": "did:plc:ada", "handle": "ada.example"}
      """
    And Bluesky answers POST "/xrpc/com.atproto.repo.putRecord" with:
      """
      {"cid": "cid", "uri": "at://did:plc:ada/app.bsky.feed.post/3kabc"}
      """
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Cross-post text" with "{280 a} @{ada}"
    And I pick the "Mastodon" network in the post details
    And I press the post button "Publish"
    Then 1 cross-post waits to go out for "Hello"
    When social post 1 goes out on account 2
    Then Bluesky got the cross-post text "{280 a} @ada.bsky.social"

  Scenario: A published post ticked for LinkedIn goes out on LinkedIn in its own words
    Given a LinkedIn account is connected
    And LinkedIn takes the cross-post as "urn:li:share:7"
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Cross-post text" with "In my own words"
    And I pick the "Mastodon" network in the post details
    And I pick the "Bluesky" network in the post details
    And I press the post button "Publish"
    Then 1 cross-post waits to go out for "Hello"
    When social post 1 goes out on account 3
    Then LinkedIn received POST "/rest/posts" with:
      """
      {"commentary": "In my own words"}
      """
