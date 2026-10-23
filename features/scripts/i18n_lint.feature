Feature: Locale lint
  mise run lint:i18n fails on a locale key no code reads, unless the allowed list names it.

  Background:
    Given the file "slices/demo/config/i18n/en.yml":
      """
      en:
        ui:
          views:
            page:
              heading: Page
              ledes:
                short: Hi
      """
    And the file "slices/demo/ui/views/page.rb":
      """
      module Demo
        module UI
          module Views
            class Page < Base
              def lede = t("ui.views.page.ledes.#{kind}")
            end
          end
        end
      end
      """

  Scenario: lint:i18n passes when code reads every key, a subclass's relative keys and prefixes among them
    Given the file ".config/i18n/allowed.yml":
      """
      []
      """
    And the file "slices/demo/ui/views/base.rb":
      """
      module Demo
        module UI
          module Views
            class Base < View
              def view_template = t(".heading")
            end
          end
        end
      end
      """
    When I run "scripts/lint/i18n $SCRATCH"
    Then it succeeds

  Scenario: lint:i18n fails on a key no code reads
    Given the file ".config/i18n/allowed.yml":
      """
      []
      """
    When I run "scripts/lint/i18n $SCRATCH"
    Then it fails
    And the output includes "ui.views.page.heading is in a locale file but no code reads it"

  Scenario: lint:i18n passes a key the allowed list names
    Given the file ".config/i18n/allowed.yml":
      """
      - ui.views.*.heading
      """
    When I run "scripts/lint/i18n $SCRATCH"
    Then it succeeds
