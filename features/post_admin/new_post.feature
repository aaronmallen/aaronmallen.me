Feature: Writing a new post
  The editor starts empty, saves drafts and publishes or schedules a post.

  Background:
    Given I am signed in to the admin

  Scenario: A new post opens an empty editor
    When I open a new post
    Then the post admin page is titled "New post"
    And the post editor offers "All posts"
    And the post field "Title" holds ""
    And the post field "Title" suggests "Post title"
    And the post field "Summary" holds ""
    And the post field "Summary" suggests "One line. Empty uses the first paragraph."
    And the post field "Body" holds ""
    And the editor sub-line reads "/writing/ · 0 words · ~1 min read"
    And the post editor offers "Save draft"
    And the post editor offers "Publish"
    And the post editor does not offer "Schedule"
    And the post editor does not offer "Delete post"
    And the post field "What changed and why" is missing
    And the editor shows Write
    And the editor tabs are labelled "Editor view"
    And the admin nav marks "Publish" as current
    And the page has no axe breaches in light or dark

  Scenario: The details drawer of a new post holds its publishing, card, cross-post and webmention fields
    When I open a new post
    Then the post details drawer is shut
    When I open the post details
    Then the post admin shows "Publishing"
    And the post admin shows "It goes live when you publish."
    And the post field "Slug" holds ""
    And the post field "Tags" suggests "ruby, patterns"
    And the post field "Publish time (Chicago)" holds ""
    And the post field "Card title" holds ""
    And the post field "Card image" holds ""
    And the post field "Canonical link" holds ""
    And the post admin shows "Only when the post title reads badly on its own. Blank uses the title."
    And the post admin shows "A link to an image you host. Blank uses the site's share image."
    And the post admin shows "Only when this went out somewhere else first. Blank points at this site."
    And the post admin shows "Cross-post text"
    And the post admin shows "Adds the webmention link tag and accepts new ones."
    And the page has no axe breaches in light or dark

  Scenario: Saving a draft keeps it and returns to its editor
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post body with:
      """
      one two
      """
    And I fill in the post details "Tags" with "Ruby, hanami, ruby"
    And I press the post button "Save draft"
    Then the post admin shows "Draft saved"
    And the posts table has a row with:
      | title | slug  | status | body    | published_at |
      | Hello | hello | draft  | one two | null         |
    And the post "Hello" carries the tags "hanami, ruby"
    And I am on "/admin/posts/1/edit"

  Scenario: A draft keeps its summary trimmed, its social card and its publish time
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post "Summary" with "  What it is about  "
    And I fill in the post details "Card title" with "On the card"
    And I fill in the post details "Card image" with "https://example.com/card.png"
    And I fill in the post details "Canonical link" with "https://elsewhere.example/hello"
    And I fill in the post details "Publish time (Chicago)" with "2030-09-07T10:30"
    And I press the post button "Save draft"
    Then the post toast says "Draft saved"
    And the posts table has a row with:
      | title | summary          | og_title    | og_image_url                 | canonical_url                   | status |
      | Hello | What it is about | On the card | https://example.com/card.png | https://elsewhere.example/hello | draft  |
    And the post "Hello" goes live at "2030-09-07T15:30:00Z"

  Scenario: A blank summary saves as nothing written
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post "Summary" with "   "
    And I press the post button "Save draft"
    Then the post toast says "Draft saved"
    And the posts table has a row with:
      | title | summary |
      | Hello |         |

  Scenario: The body keeps its spaces and loses Windows line endings
    Given I open a new post
    When I send the post form to "/admin/posts" with:
      | intent       | draft                    |
      | post[title]  | Hello                    |
      | post[body]   | \u0020\u0020\u0020\u0020code\r\ntwo\rthree\r\n |
    Then the post admin answers 302
    And the body of the post "Hello" is "\u0020\u0020\u0020\u0020code\ntwo\nthree\n"

  Scenario Outline: An intent the editor does not know saves a draft
    Given I wrote a draft post "Old"
    And I open a new post
    When I send the post form to "<path>" with:
      | intent      | <intent> |
      | post[title] | <title>  |
      | post[slug]  | <slug>   |
    Then the posts table has a row with:
      | title   | status | published_at |
      | <title> | draft  | null         |

    Examples:
      | path              | intent | title | slug  |
      | /admin/posts      | launch | Hello | hello |
      | /admin/posts/{Old} | x      | Old   | old   |

  Scenario: Publishing a new post with no publish time puts it live now
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I press the post button "Publish"
    Then the post toast says "Published"
    And the post "Hello" went live just now

  Scenario: Publishing with a past publish time keeps that time
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Publish time (Chicago)" with "2026-09-07T10:30"
    And I press the post button "Publish"
    Then the posts table has a row with:
      | title | status    |
      | Hello | published |
    And the post "Hello" goes live at "2026-09-07T15:30:00Z"

  Scenario: A future publish time schedules the post
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I fill in the post details "Publish time (Chicago)" with "2030-09-07T10:30"
    Then the post admin shows "Publishing schedules it for this date."
    When I press the post button "Schedule"
    Then the post toast says "Scheduled for Sep 7, 2030, 10:30"
    And the posts table has a row with:
      | title | status    |
      | Hello | scheduled |
    And the post "Hello" goes live at "2030-09-07T15:30:00Z"

  Scenario: A blank title saves nothing and keeps what was typed
    When I open a new post
    And I fill in the post "Title" with "  "
    And I fill in the post body with:
      """
      kept
      """
    And I press the post button "Save draft"
    Then the post field error reads "Add a title."
    And the post field "Body" holds "kept"
    And the post details drawer is shut
    And the posts table holds 0 rows
    And the page has no axe breaches in light or dark

  Scenario: A failed save answers 422 and comes back on the tab it came from
    Given I open a new post
    When I send the post form to "/admin/posts" with:
      | view        | preview |
      | intent      | draft   |
      | post[title] |         |
    Then the post admin answers 422
    And the editor shows Preview
    When I send the post form to "/admin/posts" with:
      | view        | gallery |
      | intent      | draft   |
      | post[title] |         |
    Then the editor shows Write

  Scenario: A failed update comes back on the tab it came from
    Given I wrote a draft post "Draft"
    And I open the editor for "Draft"
    When I send the post form to "/admin/posts/{Draft}" with:
      | view        | preview |
      | intent      | draft   |
      | post[title] |         |
    Then the post admin answers 422
    And the editor shows Preview

  Scenario: A taken slug opens the details drawer and saves nothing
    Given I wrote a draft post "Hello"
    When I open a new post
    And I fill in the post "Title" with "Hello"
    And I press the post button "Save draft"
    Then the post details drawer is open
    And the post field error reads "Another post has this slug."
    And the posts table holds 1 rows

  Scenario Outline: The editor refuses a bad field
    When I open a new post
    And I fill in the post "Title" with "<title>"
    And I fill in the post details "<field>" with "<value>"
    And I press the post button "<button>"
    Then the post field error reads "<error>"
    And the posts table holds 0 rows

    Examples:
      | title | field                  | value            | button     | error                                                |
      | Tags  | Tags                   |                  | Save draft | That slug is taken by a site page.                   |
      | Hello | Slug                   | Hello World      | Save draft | Use lowercase letters, numbers and single dashes.    |
      | Hello | Slug                   | -hello           | Save draft | Use lowercase letters, numbers and single dashes.    |
      | Hello | Slug                   | hello-           | Save draft | Use lowercase letters, numbers and single dashes.    |
      | Hello | Slug                   | hello--world     | Save draft | Use lowercase letters, numbers and single dashes.    |
      | Hello | Slug                   | héllo            | Save draft | Use lowercase letters, numbers and single dashes.    |
      | Hello | Slug                   | hello/world      | Save draft | Use lowercase letters, numbers and single dashes.    |
      | Hello | Tags                   | ruby, a/b        | Save draft | A tag is lowercase words joined by hyphens.          |
      | Hello | Card image             | card.png         | Save draft | Enter a link that starts with http:// or https://.   |
      | Hello | Publish time (Chicago) | 2027-03-14T02:30 | Schedule   | That time does not exist here: the clocks skip it.   |

  Scenario: The editor refuses a publish time it cannot read
    Given I open a new post
    When I send the post form to "/admin/posts" with:
      | intent          | draft            |
      | post[title]     | Hello            |
      | post[publish_at] | 2026-02-30T10:00 |
    Then the post field error reads "Enter a date and time."

  Scenario: A save with no CSRF token is refused
    Given I open a new post
    When I send the post form to "/admin/posts" with:
      | _csrf_token | none  |
      | intent      | draft |
      | post[title] | Hello |
    Then the post admin answers 403
    And the posts table holds 0 rows
