Feature: Editing a post
  The editor fills from the post, guards what a published post can change and asks for a note when its body does.

  Background:
    Given I am signed in to the admin

  Scenario: A scheduled post fills the editor and offers Schedule
    Given I wrote a scheduled post "Hello" with:
      | body         | one two              |
      | tags         | ruby, hanami         |
      | published_at | 2030-09-07T15:30:00Z |
    When I open the editor for "Hello"
    Then the post admin page is titled "Hello"
    And the post field "Title" holds "Hello"
    And the post field "Body" holds "one two"
    And the post editor offers "Schedule"
    And the post field "What changed and why" is missing
    When I open the post details
    Then the post field "Slug" holds "hello"
    And the post field "Tags" holds "hanami, ruby"
    And the post field "Publish time (Chicago)" holds "2030-09-07T10:30"
    And the post admin shows "Publishing schedules it for this date."
    And the page has no axe breaches in light or dark

  Scenario: The tags field suggests the public tags and leaves the private ones out
    Given I wrote a draft post "Hello" with:
      | tags | ruby, hanami |
    And the tags table holds:
      | name   | color   | scope   |
      | secret | mk-pink | private |
    When I open the editor for "Hello"
    Then the post tag field suggests "hanami, ruby"

  Scenario: The preview of a saved post shows its title, date, tags and body
    Given I wrote a scheduled post "Hello" with:
      | body         | one two              |
      | tags         | ruby, hanami         |
      | published_at | 2030-09-07T15:30:00Z |
    When I open the editor for "Hello"
    And I pick the "Preview" editor tab
    Then the post preview shows "Hello" as the title
    And the post preview shows "one two" as the body
    And the post admin shows "Sep 7, 2030"
    And the page has no axe breaches in light or dark

  Scenario: A published post locks its slug and publish time and offers Save
    Given I wrote a published post "Hello" with:
      | tags | ruby, hanami |
    When I open the editor for "Hello"
    Then the post field "Title" holds "Hello"
    And the post editor offers "Save"
    And the post editor does not offer "Save draft"
    And the post editor does not offer "Publish"
    And the post admin does not show "It goes live when you publish."
    And the post editor offers "Analytics"
    When I open the post details
    Then the post field "Tags" holds "hanami, ruby"
    And the post field "Slug" is read-only
    And the post field "Publish time (Chicago)" is read-only
    And the page has no axe breaches in light or dark

  Scenario: A draft has no analytics link, no note box and an empty publish time
    Given I wrote a draft post "Hello"
    When I open the editor for "Hello"
    Then the post editor does not offer "Analytics"
    And the post field "Summary" holds ""
    And the post field "What changed and why" is missing
    When I open the post details
    Then the post field "Publish time (Chicago)" holds ""

  Scenario: The sub-line counts the words and read time of the post
    Given I wrote a draft post "Hello" with:
      | body | word word word word word word word word word word word word word word word word word word word word |
    When I open the editor for "Hello"
    Then the editor sub-line reads "/writing/hello · 20 words · ~1 min read"

  Scenario: The editor fills the summary, social card and slug hint the post carries
    Given I wrote a draft post "Héllo, Wörld!" with:
      | summary       | What it is about                |
      | og_title      | On the card                     |
      | og_image_url  | https://example.com/card.png    |
      | canonical_url | https://elsewhere.example/hello |
      | slug          | x                               |
    When I open the editor for "Héllo, Wörld!"
    Then the post field "Summary" holds "What it is about"
    When I fill in the post details "Slug" with ""
    Then the post field "Slug" suggests "hello-world"
    And the post field "Card title" holds "On the card"
    And the post field "Card image" holds "https://example.com/card.png"
    And the post field "Canonical link" holds "https://elsewhere.example/hello"

  Scenario: A draft with a past publish time reads Publish
    Given I wrote a draft post "Hello" with:
      | published_at | 1 hour ago |
    When I open the editor for "Hello"
    Then the post editor offers "Publish"
    And the post editor does not offer "Schedule"

  Scenario: A post that does not exist is not found
    When I visit "/admin/posts/999/edit"
    Then the server answers 404

  Scenario: Updating a draft saves the new title, slug and body with no note
    Given I wrote a draft post "Hello" with:
      | body | one |
    When I open the editor for "Hello"
    And I fill in the post "Title" with "Changed"
    And I fill in the post body with:
      """
      new
      """
    And I fill in the post details "Slug" with "changed"
    And I press the post button "Save draft"
    Then the post toast says "Draft saved"
    And the posts table has a row with:
      | title   | slug    | body | status |
      | Changed | changed | new  | draft  |
    And the post "Changed" has no edit notes

  Scenario: Publishing a draft from its editor
    Given I wrote a draft post "Hello"
    When I open the editor for "Hello"
    And I press the post button "Publish"
    Then the post toast says "Published"
    And the post "Hello" went live just now

  Scenario: A scheduled post saved as a draft goes back to a draft
    Given I wrote a scheduled post "Hello"
    When I open the editor for "Hello"
    And I press the post button "Save draft"
    Then the posts table has a row with:
      | title | status |
      | Hello | draft  |

  Scenario: A scheduled post changes its body with no note and stays scheduled
    Given I wrote a scheduled post "Hello" with:
      | body | one |
    When I open the editor for "Hello"
    And I fill in the post body with:
      """
      two
      """
    And I press the post button "Schedule"
    Then the posts table has a row with:
      | title | status    | body |
      | Hello | scheduled | two  |
    And the post "Hello" has no edit notes

  Scenario: A scheduled time in the hour the clocks repeat stays put
    Given I wrote a scheduled post "Hello" with:
      | published_at | 2030-11-03T07:30:00Z |
    When I open the editor for "Hello"
    And I fill in the post "Title" with "Goodbye"
    And I press the post button "Schedule"
    Then the post toast says "Scheduled for Nov 3, 2030, 01:30"
    And the post "Goodbye" goes live at "2030-11-03T07:30:00Z"

  Scenario: A duplicate slug on update changes nothing and keeps the form's action
    Given I wrote a draft post "Hello"
    And I wrote a draft post "Draft"
    When I open the editor for "Draft"
    And I fill in the post "Title" with "Changed"
    And I fill in the post details "Slug" with "hello"
    And I press the post button "Save draft"
    Then the post field error reads "Another post has this slug."
    And the posts table has a row with:
      | title | slug  |
      | Draft | draft |
    When I fill in the post details "Slug" with "fresh"
    And I press the post button "Save draft"
    Then the posts table has a row with:
      | title   | slug  |
      | Changed | fresh |

  Scenario: Invalid input to a post that does not exist is not found
    Given I open a new post
    When I send the post form to "/admin/posts/999" with:
      | intent      | draft |
      | post[title] |       |
    Then the post admin answers 404

  Scenario: A post with a blank social card falls back to the site's link, share image and the title
    Given I wrote a published post "Hello"
    Then the post page "/writing/hello" heads with "link[rel='canonical']" as "/writing/hello$"
    And the post page "/writing/hello" heads with "meta[property='og:image']" as "/share-.+png$"
    And the post page "/writing/hello" heads with "meta[property='og:title']" as "^Hello$"
