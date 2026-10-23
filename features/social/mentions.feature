Feature: Mentions in the social composer
  Typing @ in a part offers the people in the directory, inserts a token for the one I pick, and lets me add someone
  new without leaving the composer.

  Background:
    Given Mastodon and Bluesky are connected
    And I am signed in to the admin

  Rule: With people in the directory

    Background:
      Given the people table holds:
        | key          | name         | mastodon_handle  | bluesky_handle   | bluesky_did  |
        | ada-lovelace | Ada Lovelace | @ada@ruby.social | ada.bsky.social  | did:plc:ada  |
        | grace-hopper | Grace Hopper | @grace@ruby.social | null           | null         |
        | alan-kay     | Alan Kay     | null             | alan.bsky.social | did:plc:alan |
      And the social composer remembers the accounts "mastodon,bluesky"

    Scenario: The list opens on @ with everyone grouped by network, handles shown and Add New last
      When I type "hello" in social part 1
      Then the social mention list is shut
      When I type " @" in social part 1
      Then the social mention names read "Ada Lovelace, Grace Hopper, Alan Kay"
      And the social mention groups read "mastodon and bluesky, mastodon only, bluesky only"
      And the social page shows "alan.bsky.social" in ".compose-mention:has-text('Alan Kay') .compose-mention-handles"
      And the last social mention choice is "Add New"
      And the page has no axe breaches in light or dark

    Scenario Outline: The list narrows by name or handle as I type
      When I type "<typed>" in social part 1
      Then the social mention names read "<names>"
      And the social mention groups read "<groups>"

      Examples:
        | typed  | names                  | groups                             |
        | @ad    | Ada Lovelace           | mastodon and bluesky               |
        | @bsky  | Ada Lovelace, Alan Kay | mastodon and bluesky, bluesky only |
        | @grace | Grace Hopper           | mastodon only                      |

    Scenario: Nobody matching leaves only Add New
      When I type "@zzz" in social part 1
      Then the social mention choices read "Add New"

    Scenario: An @ inside a word opens nothing
      When I type "mail ada@" in social part 1
      Then the social mention list is shut

    Scenario: The list opens in a part added to the thread
      When I add a part to the social thread
      And I type "@gr" in social part 2
      Then the social mention names read "Grace Hopper"

    Scenario: The list shuts when the text box loses focus
      When I type "@" in social part 1
      And I click the social page heading
      Then the social mention list is shut

    Scenario: The arrow keys move through the list and a screen reader hears who is under them
      When I type "@" in social part 1
      Then the chosen social mention is "Ada Lovelace"
      When I press ArrowDown in the social composer
      Then the chosen social mention is "Grace Hopper"
      And the "[data-social-body]" on the social page has "aria-activedescendant" set to "social-mentions-grace-hopper"
      When I press ArrowDown in the social composer
      And I press ArrowUp in the social composer
      Then the chosen social mention is "Grace Hopper"

    Scenario Outline: Enter or Tab inserts the token and keeps the focus in the text box
      When I type "hi @<typed>" in social part 1
      And I press <key> in the social composer
      Then social part 1 reads "hi @{<key_name>} "
      And the focus is in a social part

      Examples:
        | typed | key   | key_name     |
        | gr    | Enter | grace-hopper |
        | ad    | Tab   | ada-lovelace |

    Scenario: Escape shuts the list with the text as typed, then Enter is a line break again
      When I type "hi @gr" in social part 1
      And I press Escape in the social composer
      Then the social mention list is shut
      And social part 1 reads "hi @gr"
      And social part 1 has no "aria-activedescendant"
      When I press Enter in the social composer
      Then social part 1 reads "hi @gr\n"

    Scenario: Only the word at the caret is replaced
      When I type "@ad" in social part 1
      And I press Enter in the social composer
      And I type "and @kay" in social part 1
      And I press Enter in the social composer
      Then social part 1 reads "@{ada-lovelace} and @{alan-kay} "

    Scenario: A click inserts the person clicked
      When I type "@" in social part 1
      And I pick "Alan Kay" from the social mention list
      Then social part 1 reads "@{alan-kay} "

    Scenario: On a phone the list fits the screen and a tap inserts the person
      Given I use a phone
      When I type "@" in social part 1
      Then the social page does not scroll sideways
      And the social mention list fits the screen
      When I pick "Grace Hopper" from the social mention list
      Then social part 1 reads "@{grace-hopper} "

    Scenario: The counters count the handle each network gets
      When I type "hi @kay" in social part 1
      And I press Enter in the social composer
      Then the social composer counts "Mastodon 12/500, Bluesky 21/300, LinkedIn 12/3000"

    Scenario: A mention that runs a part over the limit turns it pink and stops the send
      When I write "@{alan-kay} {a*285}" in social part 1
      Then the Bluesky social counter is over
      And the social send button is disabled

    Scenario: The preview shows each network's text with the handle or a plain name in place
      When I type "hello" in social part 1
      Then the social page has no visible "[data-social-preview]"
      When I write "" in social part 1
      And I type "hi @ad" in social part 1
      And I press Enter in the social composer
      Then the social page shows "hi @ada@ruby.social" in "[data-social-preview-line='mastodon'] [data-social-preview-text]"
      And the social page shows "hi @ada.bsky.social" in "[data-social-preview-line='bluesky'] [data-social-preview-text]"
      When I write "" in social part 1
      And I type "hi @kay" in social part 1
      And I press Enter in the social composer
      Then the social page shows "hi Alan Kay" in "[data-social-preview-line='mastodon'] [data-social-preview-text]"
      When I toggle the Bluesky social account
      Then the social page has no visible "[data-social-preview-line='bluesky']"

    Scenario: A screen reader hears the list tied to the text box, the match count and the choice
      Then the "[data-social-body]" on the social page has "aria-controls" set to "social-mentions"
      And the "[data-social-body]" on the social page has "aria-autocomplete" set to "list"
      And the "[data-social-body]" on the social page has "aria-haspopup" set to "listbox"
      When I type "@bsky" in social part 1
      Then the social page shows "2 people" in "[data-social-mention-status]"
      When I write "" in social part 1
      And I type "@gr" in social part 1
      And I press Enter in the social composer
      Then the social page shows "Mentioned Grace Hopper" in "[data-social-mention-status]"

  Rule: With nobody in the directory

    Scenario: The list offers only Add New
      When I visit "/admin/social"
      And I type "@" in social part 1
      Then the social mention choices read "Add New"

  Rule: Adding someone new

    Background:
      Given the people table holds:
        | key          | name         | mastodon_handle    |
        | grace-hopper | Grace Hopper | @grace@ruby.social |
      And the social composer remembers the accounts "mastodon,bluesky"

    Scenario Outline: Enter, Tab or a click on Add New opens the dialog and inserts no token
      When I type "hi @<typed>" in social part 1
      And I <open> the social Add New row
      Then the person dialog is open
      And the person dialog's "name" reads "<typed>"
      And social part 1 reads "hi @<typed>"
      And the page has no axe breaches in light or dark

      Examples:
        | typed | open             |
        | zed   | press Enter on   |
        | zed   | press Tab on     |
        |       | click            |

    Scenario: The key follows the name until I edit the key
      When I type "hi @zed" in social part 1
      And I press Enter in the social composer
      And I fill in the person dialog's "name" with "Zed Shaw"
      Then the person dialog's "key" reads "zed-shaw"
      When I fill in the person dialog's "key" with "zed"
      And I fill in the person dialog's "name" with "Zed A Shaw"
      Then the person dialog's "key" reads "zed"

    Scenario: A refusal shows in the dialog and keeps what I entered
      When I type "hi @zed" in social part 1
      And I press Enter in the social composer
      And I fill in the person dialog's "mastodon_handle" with "zed"
      And I press "Add person" in the person dialog
      Then the person dialog shows "#person-mastodon_handle-error"
      And the person dialog's "name" reads "zed"
      And social part 1 reads "hi @zed"

    Scenario: A good save stores the person and puts their token in place of what I typed
      When I type "hi @zed" in social part 1
      And I press Enter in the social composer
      And I fill in the person dialog's "name" with "Zed Shaw"
      And I fill in the person dialog's "mastodon_handle" with "@zed@ruby.social"
      And I press "Add person" in the person dialog
      Then the person dialog is shut
      And the people table has a row with:
        | key      | name     |
        | zed-shaw | Zed Shaw |
      And social part 1 reads "hi @{zed-shaw} "
      And the focus is in a social part
      And the social page shows "hi @zed@ruby.social" in "[data-social-preview-line='mastodon'] [data-social-preview-text]"
      And the social page shows "hi Zed Shaw" in "[data-social-preview-line='bluesky'] [data-social-preview-text]"
      When I type "@" in social part 1
      Then the social mention names read "Grace Hopper, Zed Shaw"

    Scenario: A form that fails to load leaves me in the composer with the text
      Given the new person form fails with 502
      When I type "hi @zed" in social part 1
      And I press Enter in the social composer
      Then the social page shows "The new person form didn't load · try again" in ".toast-failed"
      And I am on "/admin/social"
      And social part 1 reads "hi @zed"
      And the focus is in a social part
      And the person dialog is shut

    Scenario: A request that gets no answer leaves me in the composer with the text
      Given the browser cannot reach the server from the social page
      When I type "hi @zed" in social part 1
      And I press Enter in the social composer
      Then the social page shows "The new person form didn't load · try again" in ".toast-failed"
      And social part 1 reads "hi @zed"

    Scenario Outline: Cancel or Escape shuts the dialog and keeps the post text
      When I type "hi @zed" in social part 1
      And I press Enter in the social composer
      And I <close> the person dialog
      Then the person dialog is shut
      And social part 1 reads "hi @zed"

      Examples:
        | close         |
        | cancel        |
        | press Escape in |
