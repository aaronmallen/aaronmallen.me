Feature: Social composer
  The composer writes one post or a thread for the connected accounts and counts each part as each network will.

  Background:
    Given Mastodon and Bluesky are connected
    And I am signed in to the admin

  Scenario: A new post opens with one empty part counted for each network
    When I visit "/admin/social"
    Then the social page has 1 "[data-social-part]"
    And the social composer counts "Mastodon 0/500, Bluesky 0/300, LinkedIn 0/3000"
    And the social page has no "[data-social-body][autofocus]"
    And the social account targets are "1,2"
    And the picked social accounts are "mastodon"
    And the social page has 1 "form[data-social-composer][data-social-restore]"
    And the page has no axe breaches in light or dark

  Scenario: Opened to write, the composer focuses the first part only
    When I visit "/admin/social?write=1"
    Then the social page has 1 "[data-social-part] [data-social-body][autofocus]"
    And the social page source holds "<template data-social-part-template"
    And the social part template has no autofocus

  Scenario: The sub-line names both accounts and counts the queue
    Given the social posts:
      | text  | status    |
      | later | scheduled |
    When I visit "/admin/social"
    Then the social page shows "Cross-posting to @aaronmallen@ruby.social and @ada.example · 1 queued" in ".page-head-sub"

  Scenario Outline: The server counts each part as each network sends it
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada.bsky.social | did:plc:ada |
    When I send the social composer:
      | accounts |        |
      | parts    | <text> |
    Then the social composer says "Pick a network"
    And the social composer counts "<counts>"

    Examples:
      | text                            | counts                                            |
      | {site}/writing/hello there      | Mastodon 29/500, Bluesky 54/300, LinkedIn 55/3000 |
      | https://example.com/hello there | Mastodon 29/500, Bluesky 38/300, LinkedIn 38/3000 |
      | hi @{ada}                       | Mastodon 7/500, Bluesky 19/300, LinkedIn 15/3000  |

  Scenario: Counting a link elsewhere makes no short link
    When I send the social composer:
      | accounts |                                 |
      | parts    | Read https://example.com/b      |
    Then the social composer counts "Mastodon 28/500, Bluesky 37/300, LinkedIn 37/3000"
    And the short_links table holds 0 rows

  Scenario: The counters tag links to the site's own host
    When I visit "/admin/social"
    Then every social counter tags the site's host

  Scenario: The directory ships as a hidden list of people to mention, Add New last
    Given the people table holds:
      | key          | name         |
      | ada-lovelace | Ada Lovelace |
    When I visit "/admin/social"
    Then the social page has 1 "[data-social-mentions][hidden]"
    And the social mention options read "Ada Lovelace // Add New"

  Scenario: With nobody in the directory the list holds only Add New
    When I visit "/admin/social"
    Then the social mention options read "Add New"
    And the social page has 1 "[data-social-mentions] a[role='option'][href='/admin/contacts/new?reply=mention']"
    And the social page source holds "<noscript><p class=\"hint\"><a href=\"/admin/contacts/new\">"

  Scenario: The people dialog sits outside the composer form in the dialog shell
    When I visit "/admin/social"
    Then the social page has 1 "dialog#person-dialog[data-person-dialog]"
    And the social page has no "form[data-social-composer] dialog#person-dialog"
    And the social page has 1 "dialog#person-dialog.dialog > .dialog-box > .dialog-head > h2#person-dialog-title + button[data-dialog-close]"

  Scenario: The preview shows each network's handle or a plain name in place of a mention, part by part
    Given the people table holds:
      | key   | name         | mastodon_handle    | bluesky_handle  | bluesky_did |
      | ada   | Ada Lovelace | @ada@ruby.social   | ada.bsky.social | did:plc:ada |
      | grace | Grace Hopper | @grace@ruby.social | null            | null        |
    And the social posts:
      | text                      | status | targets          |
      | hi @{ada} // and @{grace} | draft  | mastodon,bluesky |
    When I open social post 1 in the composer
    Then the social page lists "[data-social-preview-line='mastodon'] [data-social-preview-text]" as "hi @ada@ruby.social // and @grace@ruby.social"
    And the social page lists "[data-social-preview-line='bluesky'] [data-social-preview-text]" as "hi @ada.bsky.social // and Grace Hopper"
    And the page has no axe breaches in light or dark

  Scenario: The preview hides for a part with no mention and for a network the post skips
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle  | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada.bsky.social | did:plc:ada |
    And the social posts:
      | text      | status | targets  |
      | hello     | draft  | mastodon |
      | hi @{ada} | draft  | mastodon |
    When I open social post 1 in the composer
    Then the social page has 1 "[data-social-preview][hidden]"
    When I open social post 2 in the composer
    Then the social page has 1 "[data-social-preview-line='bluesky'][hidden]"

  Scenario: The counters get each network's handle for everyone with a key
    Given the people table holds:
      | key   | name            | mastodon_handle    | bluesky_handle  | bluesky_did |
      | ada   | Ada Lovelace    | @ada@ruby.social   | ada.bsky.social | did:plc:ada |
      | grace | Grace Hopper    | @grace@ruby.social | null            | null        |
      | null  | Charles Babbage | null               | null            | null        |
    When I visit "/admin/social"
    Then the social handles give "ada" on bluesky as "@ada.bsky.social"
    And the social handles give "grace" on bluesky as "Grace Hopper"
    And the social handles hold no blank key

  Scenario: Every connected account is listed by network with the first one ticked
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    When I visit "/admin/social"
    Then the social account targets are "1,3,2"
    And the picked social accounts are "1"
    And the social account rows read "@aaronmallen ruby.social // @ada hachyderm.io // @ada.example"
    And the social account groups read "Post as, Mastodon, Bluesky"
    And the social accounts toggle reads "1 of 3"
    And the "a[href='/admin/settings/services#services']" on the social page has "href" set to "/admin/settings/services#services"
    And the social page shows "Manage accounts" in ".compose-accounts-foot a"

  Scenario: A draft that picked an account opens with only that account ticked
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    And the social posts:
      | text | status | accounts |
      | hi   | draft  | 3        |
    When I open social post 1 in the composer
    Then the picked social accounts are "3"
    And the social accounts toggle reads "1 of 3"
    And the social page has no "[data-social-restore]"

  Scenario: With scripts off, the accounts ticked in the menu decide where a post goes
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    And the social posts:
      | text  | status | targets                   |
      | hello | draft  | mastodon,bluesky,linkedin |
    When I post social post 1 now with scripts off, leaving only account 3 ticked
    Then social post 1 is scheduled
    And social post 1 goes to "mastodon"
    And social post 1 picked the accounts "3"

  Scenario: The chips show each picked account, tinted by network, and a chip unticks its account
    Given the social composer remembers the accounts "mastodon,bluesky"
    Then the social account chips read "@aaronmallen, @ada.example"
    And the social page shows "@ada.example" in ".compose-chip.bluesky"
    When I toggle the Bluesky social account
    Then the social accounts toggle reads "1 of 2"
    When I toggle the Bluesky social account
    And I remove the social chip "@ada.example"
    Then the social account chips read "@aaronmallen"
    And the page has no axe breaches in light or dark

  Scenario: With no account picked the composer asks for one
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I write "hello" in social part 1
    And I remove the social chip "@aaronmallen@ruby.social"
    And I remove the social chip "@ada.example"
    Then the social page shows "Pick at least one account" in ".compose-to"

  Scenario: Everywhere picks every account and Clear drops them all
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I toggle the Bluesky social account
    And I click "Everywhere"
    Then the social accounts toggle reads "2 of 2"
    When I click "Clear"
    Then the social page shows "Pick at least one account" in ".compose-to"

  Scenario: Two picked accounts with the same handle show their hosts
    Given my Mastodon account "ada" on "hachyderm.io" is connected
    And my Mastodon account "ada" on "mastodon.social" is connected
    And the social composer remembers the accounts "3,4"
    Then the social page lists ".compose-chip-host:not([hidden])" as "hachyderm.io // mastodon.social"

  Scenario: Past three chips the rest fold into a button that opens the menu
    Given my Bluesky account "grace.example" is connected
    And my Mastodon account "ada" on "hachyderm.io" is connected
    And the social composer remembers the accounts "1,2,3,4"
    Then the social account chips read "@aaronmallen, @ada, @ada.example"
    When I click "+1 more"
    Then the social page has 1 ".compose-accounts[open]"

  Scenario: A group link ticks or unticks every account in a group of more than one
    Given my Bluesky account "grace.example" is connected
    And my Mastodon account "ada" on "hachyderm.io" is connected
    And the social composer remembers the accounts "1,2,3,4"
    When I open the social accounts menu
    And I press "none" in the bluesky social account group
    And I press "all 2" in the bluesky social account group
    Then the social accounts toggle reads "4 of 4"

  Scenario: A group of one has no group link and five accounts or fewer have no search
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I open the social accounts menu
    Then the social page has no visible ".compose-account-group.bluesky [data-social-group]"
    And the social page has no visible ".compose-accounts-find"

  Scenario: The accounts menu shuts on Escape and on a click outside it
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I open the social accounts menu
    And I press Escape in the social composer
    Then the social page has no ".compose-accounts[open]"
    When I open the social accounts menu
    And I click outside the social accounts menu
    Then the social page has no ".compose-accounts[open]"

  Scenario: More than five accounts get a search that filters by handle
    Given my Mastodon account "ada" on "a.example" is connected
    And my Mastodon account "ada" on "b.example" is connected
    And my Mastodon account "ada" on "c.example" is connected
    And my Bluesky account "grace.example" is connected
    And the social composer remembers the accounts "1,2,3,4,5,6"
    When I open the social accounts menu
    And I fill in "Find an account" with "@GRACE"
    Then the social page has 1 ".compose-account:visible"
    And the social page shows "@grace.example" in ".compose-account"
    When I fill in "Find an account" with "zed"
    Then the social page shows "No account matches" in ".compose-accounts-menu"
    When I fill in "Find an account" with "ada"
    And I press "none" in the mastodon social account group
    Then the social accounts toggle reads "3 of 6"

  Scenario: On a phone the account rows and chip buttons grow to touch size and pass axe
    Given I use a phone
    And the social composer remembers the accounts "mastodon,bluesky"
    Then the first ".compose-chip-remove" on the social page is at least 44 pixels tall
    When I open the social accounts menu
    Then the first ".compose-account" on the social page is at least 44 pixels tall
    And the page has no axe breaches in light or dark

  Scenario: A new post starts with the accounts last sent to, or the first one
    Given the social composer remembers the accounts "bluesky"
    Then the picked social accounts are "bluesky"
    Given the social composer remembers the accounts "none still connected"
    Then the picked social accounts are "mastodon"
    Given the social composer remembers nothing
    Then the picked social accounts are "mastodon"

  Scenario: The composer remembers the accounts a sent or scheduled post went to, not a draft's
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I toggle the Mastodon social account
    And I write "hello" in social part 1
    And I click "Post now"
    Then the social toast says "Queued for Bluesky"
    When I visit "/admin/social"
    Then the picked social accounts are "bluesky"
    When I write "later" in social part 1
    And I choose "schedule" on the social page
    And I fill in "Send time (Chicago)" with "2099-03-01T09:30"
    And I click "Schedule"
    Then the social toast says "Scheduled for"
    When I visit "/admin/social"
    Then the picked social accounts are "bluesky"
    When I toggle the Mastodon social account
    And I toggle the Bluesky social account
    And I write "a draft" in social part 1
    And I click "Save draft"
    Then the social toast says "Draft saved"
    When I visit "/admin/social"
    Then the picked social accounts are "bluesky"

  Scenario: A draft keeps its own accounts when it opens
    Given the social posts:
      | text | status | targets | accounts |
      | hi   | draft  | bluesky | 2        |
    And the social composer remembers the accounts "mastodon"
    When I open social post 1 in the composer
    Then the picked social accounts are "bluesky"

  Scenario: Parts come and go in a thread and keep their text
    Given the social composer remembers the accounts "mastodon,bluesky"
    Then the social page has no visible "[data-social-remove]"
    When I add a part to the social thread
    Then the social page has 2 "[data-social-part]"
    And the social page has 2 "[data-social-remove]:visible"
    When I write "first" in social part 1
    And I write "second" in social part 2
    And I remove the last social part
    Then the social page has 1 "[data-social-part]"
    And the social composer holds "first"

  Scenario: Each part counts on its own and a LinkedIn thread counts as the joined post
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I add a part to the social thread
    And I write "hello" in social part 1
    Then the social composer counts "Mastodon 5/500, Bluesky 5/300, LinkedIn 7/3000, Mastodon 0/500, Bluesky 0/300, LinkedIn 7/3000"

  Scenario Outline: The counters count typed text as the server does
    Given the people table holds:
      | key | name         | mastodon_handle  | bluesky_handle | bluesky_did |
      | ada | Ada Lovelace | @ada@ruby.social | ada.example    | did:plc:ada |
    And the social composer remembers the accounts "mastodon,bluesky"
    When I write "<text>" in social part 1
    Then the social composer counts "<counts>"
    When I send the social composer:
      | accounts |        |
      | parts    | <text> |
    Then the social composer counts "<counts>"

    Examples:
      | text                                            | counts                                              |
      | hello                                           | Mastodon 5/500, Bluesky 5/300, LinkedIn 5/3000      |
      | Read {site}/writing/hello and tell me           | Mastodon 40/500, Bluesky 65/300, LinkedIn 66/3000   |
      | see (https://example.com/a(b))                  | Mastodon 29/500, Bluesky 38/300, LinkedIn 38/3000   |
      | see (https://x.y/z))                            | Mastodon 30/500, Bluesky 39/300, LinkedIn 39/3000   |
      | see [https://x.y/z]                             | Mastodon 29/500, Bluesky 38/300, LinkedIn 38/3000   |
      | see https://x.y/a[b]                            | Mastodon 27/500, Bluesky 36/300, LinkedIn 36/3000   |
      | write me@https://x.y/z                          | Mastodon 22/500, Bluesky 22/300, LinkedIn 22/3000   |
      | {site}                                          | Mastodon 23/500, Bluesky 35/300, LinkedIn 36/3000   |
      | {site}/a?b=c#d                                  | Mastodon 23/500, Bluesky 42/300, LinkedIn 43/3000   |
      | {site}/a?ref=x                                  | Mastodon 23/500, Bluesky 30/300, LinkedIn 30/3000   |
      | {site}/a?href=x                                 | Mastodon 23/500, Bluesky 43/300, LinkedIn 44/3000   |
      | ({site}/a)                                      | Mastodon 25/500, Bluesky 38/300, LinkedIn 39/3000   |
      | see http://shares.localhost/talk                | Mastodon 27/500, Bluesky 32/300, LinkedIn 32/3000   |
      | see https://example.com/hello                   | Mastodon 27/500, Bluesky 36/300, LinkedIn 36/3000   |
      | hi @alice@mastodon.social and @bob@example.co.uk | Mastodon 18/500, Bluesky 48/300, LinkedIn 48/3000  |
      | thanks @{ada} and @{nobody}                     | Mastodon 22/500, Bluesky 30/300, LinkedIn 30/3000   |
      | not a token @{a b} or @{}                       | Mastodon 25/500, Bluesky 25/300, LinkedIn 25/3000   |
      | 👍🏽 👨‍👩‍👧 done                                     | Mastodon 8/500, Bluesky 8/300, LinkedIn 8/3000      |

  Scenario Outline: A part over a picked network's limit turns its meter pink and stops the send
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I write "<text>" in social part 1
    Then the <network> social counter is over
    And the Mastodon social counter is <mastodon>
    And the social send button is disabled
    And the social draft button is enabled

    Examples:
      | text                                   | network  | mastodon |
      | {a*301}                                | Bluesky  | under    |
      | {a*262} {site}/writing/hello           | Bluesky  | under    |
      | {a*481} (https://example.com/a(b))     | Mastodon | over     |

  Scenario: A part under the grapheme limit but over the byte limit is over and its meter is full
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I write "{👨‍👩‍👧‍👦*121}" in social part 1
    Then the Bluesky social counter is over
    And the Bluesky social meter is 100% full
    And the social send button is disabled
    When I write "{a*150}" in social part 1
    Then the Bluesky social meter is 50% full

  Scenario: A network that is off is muted and no longer stops the send
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I write "{a*301}" in social part 1
    And I toggle the Bluesky social account
    Then the Bluesky social counter is off
    And the social send button is enabled

  Scenario: The send and draft buttons follow the text and the picked networks
    Given the social composer remembers the accounts "mastodon,bluesky"
    Then the social send button is disabled
    When I write "hello" in social part 1
    Then the social send button is enabled
    When I add a part to the social thread
    And I write "{a*301}" in social part 2
    Then the social send button is disabled
    When I remove the last social part
    And I toggle the Mastodon social account
    And I toggle the Bluesky social account
    Then the social send button is disabled
    And the social draft button is disabled

  Scenario: The send time shows only while scheduling and renames the button
    Given the social composer remembers the accounts "mastodon,bluesky"
    Then the social page has no visible "#social-schedule_at"
    And the social page has a visible "[data-social-now].hint"
    When I choose "schedule" on the social page
    Then the social page has a visible "#social-schedule_at"
    And the social page shows "Schedule" in "[data-social-send]"
    And the social page has a visible "[data-social-later].hint"
    When I choose "post now" on the social page
    Then the social page has no visible "#social-schedule_at"

  Scenario: Posting what was written queues it for the picked networks
    Given the social composer remembers the accounts "mastodon,bluesky"
    When I write "hello" in social part 1
    And I click "Post now"
    Then the social toast says "Queued for Mastodon + Bluesky"
    And social post 1 is scheduled

  Scenario: Every part of a LinkedIn thread turns pink once the joined text runs over
    Given my LinkedIn account "Ada Lovelace" is connected
    And the social composer remembers the accounts "linkedin"
    When I add a part to the social thread
    And I write "{a*1500}" in social part 1
    And I write "{b*1499}" in social part 2
    Then 2 LinkedIn social counters are over
