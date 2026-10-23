Feature: A post's webmentions setting
  Each post says whether it takes webmentions, and the editor counts what it has received.

  Background:
    Given I am signed in to the admin

  Scenario Outline: A new post starts with the site's default
    Given webmentions start <default> on new posts
    When I open a new post
    And I open the post details
    Then the post admin shows "Webmentions"
    And the post admin shows "Adds the webmention link tag and accepts new ones."
    And the post field "Accept webmentions" is <state>

    Examples:
      | default | state    |
      | on      | ticked   |
      | off     | unticked |

  Scenario: A new post saves the setting as ticked, and the default when the form leaves it out
    Given webmentions start on on new posts
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I turn off "Accept webmentions" in the post details
    And I press the post button "Save draft"
    Then the posts table has a row with:
      | title | webmentions_enabled |
      | Hello | false               |
    Given webmentions start off on new posts
    When I send the post form to "/admin/posts" with:
      | intent      | draft  |
      | post[title] | Again  |
    Then the posts table has a row with:
      | title | webmentions_enabled |
      | Again | false               |

  Scenario: The editor reads the setting off the post and keeps it after a failed save
    Given I wrote a draft post "Hello"
    When I open the editor for "Hello"
    And I open the post details
    Then the post field "Accept webmentions" is unticked
    When I send the post form to "/admin/posts" with:
      | intent                    | draft |
      | post[title]               |       |
      | post[webmentions_enabled] | 0     |
    And I open the post details
    Then the post field "Accept webmentions" is unticked

  Scenario Outline: Saving turns the setting on or off
    Given I wrote a <status> post "Hello" with:
      | webmentions_enabled | <before> |
    When I open the editor for "Hello"
    And I turn <switch> "Accept webmentions" in the post details
    And I press the post button "<button>"
    Then the posts table has a row with:
      | title | webmentions_enabled | status   |
      | Hello | <after>             | <status> |

    Examples:
      | status    | before | switch | button     | after |
      | draft     | true   | off    | Save draft | false |
      | draft     | false  | on     | Save draft | true  |
      | published | true   | off    | Save       | false |

  Scenario: The editor counts every webmention the post received
    Given I wrote a draft post "Hello"
    And the post "Hello" has received webmentions:
      | status   |
      | pending  |
      | spam     |
      | approved |
      | ignored  |
    When I open the editor for "Hello"
    And I open the post details
    Then the post admin shows "4 received so far"

  Scenario: The editor counts one webmention
    Given I wrote a draft post "Hello"
    And the post "Hello" has received webmentions:
      | status  |
      | pending |
    When I open the editor for "Hello"
    And I open the post details
    Then the post admin shows "1 received so far"

  Scenario: The editor says nothing of webmentions a post has not received
    Given I wrote a draft post "Hello"
    When I open the editor for "Hello"
    And I open the post details
    Then the post admin does not show "received so far"

  Scenario: A post with webmentions off still shows approved replies but takes no new ones
    Given I wrote a published post "Quiet"
    And the post "Quiet" has received webmentions:
      | status   | type  | author |
      | approved | reply | Ada    |
    Then the post page "/writing/quiet" shows "Ada"
    And the post page "/writing/quiet" has no "link[rel='webmention']" tag in its head
    When a webmention for "/writing/quiet" comes in
    Then the webmention answer is 400

  Scenario: A post with webmentions on carries the webmention link tag
    Given I wrote a published post "Loud" with:
      | webmentions_enabled | true |
    Then the post page "/writing/loud" has a "link[rel='webmention']" tag in its head
