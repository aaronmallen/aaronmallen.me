Feature: Uploading photos in the social composer
  A photo dropped, pasted or picked onto a part uploads to the media store and waits there with an alt text field.

  Background:
    Given Mastodon and Bluesky are connected
    And I am signed in to the admin
    And I visit "/admin/social"
    And I write "hello" in social part 1

  Scenario Outline: A photo dropped, pasted or picked shows with an alt text field
    When I <hand> a photo onto social part 1
    Then social part 1 holds 1 uploaded photo
    And the social page has a visible "[data-social-photo-alt]"
    And every social photo key looks like a stored key

    Examples:
      | hand  |
      | drop  |
      | paste |
      | pick  |

  Scenario: A fifth photo on a part is refused and says why
    When I drop 4 photos onto social part 1
    And I drop a photo onto social part 1
    Then the social page shows "A part takes four photos at most." in "[role='alert']"
    And the social page has 4 "[data-social-photo]"

  Scenario: A second part takes four more
    When I drop 4 photos onto social part 1
    And I add a part to the social thread
    And I write "two" in social part 2
    And I drop 4 photos onto social part 2
    Then the social page has 2 "[data-social-photo-count]:has-text('Photos 4/4')"

  Scenario: A photo moves later and a photo comes off
    When I drop 2 photos onto social part 1
    And I move the first social photo later
    Then the first social photo key is now last
    When I remove the first social photo
    Then the social page has 1 "[data-social-photo]"

  Scenario: The preview shows the photos with their alt text
    When I drop a photo onto social part 1
    And I fill in "Alt text" with "A small square"
    Then the social page has 1 ".compose-preview-photo[alt='A small square']"

  Scenario: Saving keeps the photos in order with their alt text
    When I drop 2 photos onto social part 1
    And I give the first social photo the alt text "First"
    And I move the first social photo later
    And I click "Save draft"
    Then the social toast says "Draft saved"
    And the social photo alt texts held are ", First"

  Scenario: Photos on a part pass axe, and on a phone the photo buttons grow to touch size
    When I drop 2 photos onto social part 1
    Then the page has no axe breaches in light or dark
    Given I use a phone
    Then the first ".compose-photo-tools .bt" on the social page is at least 44 pixels tall
