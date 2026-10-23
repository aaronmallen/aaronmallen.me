Feature: Photos in the Markdown editor
  The owner drops, pastes or picks a photo in the Markdown editor, and its link lands at the cursor.

  Background:
    Given I am signed in to the admin
    And I write "Before " in a new post's body

  Scenario: A dropped photo uploads and its link lands at the cursor
    When I drop the photo file "small.png" into the post body
    Then the post body holds a link to the uploaded photo after "Before "
    And the post body's cursor sits after "Before !["
    And the page has no axe breaches in light or dark

  Scenario: A pasted photo uploads
    When I paste the photo file "small.png" into the post body
    Then the post body holds a link to the uploaded photo after "Before "

  Scenario: A photo picked from the toolbar uploads
    When I pick the photo file "small.png" from the post body's toolbar
    Then the post body holds a link to the uploaded photo after "Before "

  Scenario: A placeholder holds the cursor while the photo uploads
    Given the photo upload waits until I let it go
    When I drop the photo file "small.png" into the post body
    Then the post body reads "Before ![Uploading small.png…]()"
    When I let the photo upload go
    Then the post body holds a link to the uploaded photo after "Before "

  Scenario: A refused upload takes its placeholder out and says why
    When I drop the photo file "drawing.svg" into the post body
    Then the post body's editor says "Upload a JPEG, PNG, WebP, GIF or HEIC photo."
    And the post body reads "Before "

  Scenario: A paste that carries text stays with the browser
    When I paste the photo file "small.png" with text into the post body
    Then the browser kept the paste
    And the post body reads "Before "
