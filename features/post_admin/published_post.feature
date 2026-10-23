Feature: Saving a published post
  A published post keeps its slug and time, and a change to its body needs a note that readers see.

  Background:
    Given I am signed in to the admin
    And I wrote a published post "Hello" with:
      | body         | one                  |
      | published_at | 2026-09-01T00:00:00Z |

  Scenario: The note box sits below the body and says what readers see
    When I open the editor for "Hello"
    And I send the post form to "/admin/posts/{Hello}" with:
      | intent      | save  |
      | post[title] | Hello |
      | post[slug]  | hello |
      | post[body]  | two   |
    Then the post field "What changed and why" holds ""
    And the post field "What changed and why" suggests "Fixed the benchmark numbers; the first run used a debug build."
    And the post admin shows "Needed, and kept, only when you change the body. Readers see it on the post and in the feed."
    And the page has no axe breaches in light or dark

  Scenario: Saving a new title keeps it published at its time
    When I open the editor for "Hello"
    And I fill in the post "Title" with "Changed"
    And I save the post
    Then the post toast says "Saved"
    And the posts table has a row with:
      | title   | status    |
      | Changed | published |
    And the post "Changed" goes live at "2026-09-01T00:00:00Z"

  Scenario: A slug change is refused and changes nothing
    Given I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}" with:
      | intent      | save    |
      | post[title] | Changed |
      | post[slug]  | goodbye |
      | post[body]  | one     |
    Then the post field error reads "A published post keeps its slug."
    And the posts table has a row with:
      | title | slug  |
      | Hello | hello |

  Scenario: A body change with no note is refused and keeps the rest of the form
    Given I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}" with:
      | intent          | save    |
      | post[title]     | Changed |
      | post[slug]      | hello   |
      | post[body]      | two     |
      | post[tags]      | ruby    |
      | post[edit_note] |         |
    Then the post admin answers 422
    And the post field error reads "Say what changed and why. A published post needs a note when its body changes."
    And the post field "Title" holds "Changed"
    And the post field "Body" holds "two"
    And the posts table has a row with:
      | title | body |
      | Hello | one  |
    And the post "Hello" has no edit notes

  Scenario: A body change with its note saves both and readers see the note
    When I open the editor for "Hello"
    And I fill in the post body with:
      """
      two
      """
    And I save the post
    And I fill in the post note with "Fixed the `numbers`"
    And I save the post note
    Then the post toast says "Saved"
    And the posts table has a row with:
      | title | body | status    |
      | Hello | two  | published |
    And the post "Hello" has the edit notes "Fixed the `numbers`"
    And the post page "/writing/hello" shows "Fixed the numbers"
    And the page has no axe breaches in light or dark
    And the post feed shows "Fixed the"

  Scenario: Tags and the social card change with no note
    Given I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}" with:
      | intent             | save                         |
      | post[title]        | Hello                        |
      | post[slug]         | hello                        |
      | post[body]         | one                          |
      | post[tags]         | ruby                         |
      | post[og_title]     | On the card                  |
      | post[og_image_url] | https://example.com/card.png |
      | post[edit_note]    | Nothing to say               |
    Then the posts table has a row with:
      | title | og_title    | og_image_url                 |
      | Hello | On the card | https://example.com/card.png |
    And the post "Hello" carries the tags "ruby"
    And the post "Hello" has no edit notes

  Scenario: A body sent back with Windows line endings reads as the same body
    Given I wrote a published post "Lines" with:
      | body | one\ntwo |
    And I open the editor for "Lines"
    When I send the post form to "/admin/posts/{Lines}" with:
      | intent      | save       |
      | post[title] | Lines      |
      | post[slug]  | lines      |
      | post[body]  | one\r\ntwo |
    Then the post admin answers 302

  Scenario Outline: The note has a length limit and takes no control characters
    Given I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}" with:
      | intent          | save    |
      | post[title]     | Hello   |
      | post[slug]      | hello   |
      | post[body]      | two     |
      | post[edit_note] | <note>  |
    Then the post field error reads "<error>"
    And the posts table has a row with:
      | title | body |
      | Hello | one  |

    Examples:
      | note        | error                                         |
      | {501 a}     | Keep the note to 500 characters or fewer.     |
      | a\u0007b    | Take out the control characters.              |

  Scenario: A note of 500 characters saves
    Given I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}" with:
      | intent          | save    |
      | post[title]     | Hello   |
      | post[slug]      | hello   |
      | post[body]      | two     |
      | post[edit_note] | {500 a} |
    Then the post "Hello" has a 500 character edit note

  Scenario: A failed save keeps the note as typed
    Given I open the editor for "Hello"
    When I send the post form to "/admin/posts/{Hello}" with:
      | intent          | save         |
      | post[title]     |              |
      | post[slug]      | hello        |
      | post[body]      | two          |
      | post[edit_note] | Fixed a typo |
    Then the post field "What changed and why" holds "Fixed a typo"
