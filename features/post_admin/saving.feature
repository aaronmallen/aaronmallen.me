Feature: What a save from the post editor stores
  A save renders the body and stores what the public pages show, and refuses a slug it cannot make.

  Background:
    Given I am signed in to the admin
    And I open a new post

  Scenario: A save stores the rendered body, first paragraph, read time and word count
    When I send the post form to "/admin/posts" with:
      | intent      | draft                      |
      | post[title] | Hello                      |
      | post[slug]  | hello                      |
      | post[body]  | ## Setup\n\none *two* three |
    Then the database reads "true, true, one two three, 1, 4" for:
      """
      SELECT body_html LIKE '%<h2 id="setup">%' AS heading,
        body_html LIKE '%<em>two</em>%' AS em,
        first_paragraph, read_time, word_count
      FROM posts
      """

  Scenario: A save of a published post stores the new body's rendering and the edit note's HTML
    Given I wrote a published post "Hello" with:
      | body | old words |
    When I send the post form to "/admin/posts/{Hello}" with:
      | intent          | draft          |
      | post[title]     | Hello          |
      | post[slug]      | hello          |
      | post[body]      | new words here |
      | post[edit_note] | Fixed *it*     |
    Then the database reads "true, 3" for:
      """
      SELECT body_html = E'<p>new words here</p>\n', word_count FROM posts
      """
    And the database reads "true" for:
      """
      SELECT note_html = E'<p>Fixed <em>it</em></p>\n' FROM post_edits
      """

  Scenario: A blank slug is refused when the title has no letter or number
    When I send the post form to "/admin/posts" with:
      | intent      | draft |
      | post[title] | !!!   |
      | post[slug]  |       |
    Then the post admin answers 422
    And the post field error reads "Add a slug with a letter or number in it."
    And the posts table holds 0 rows
