Feature: Shopping cart
  Cart manipulation with a logged-in user as Background.

  Background:
    Given a logged-in user

  Scenario: Add a single item to the cart
    When the user adds 1 "widget" to the cart
    Then the cart contains 1 items

  Scenario: Add multiple items
    When the user adds 3 "gadget" to the cart
    And the user adds 2 "widget" to the cart
    Then the cart contains 5 items

  Scenario: Apply a discount code
    When the user adds 1 "widget" to the cart
    And the user applies discount code "SUMMER20"
    Then the cart total reflects the discount

  Scenario Outline: Cart latency under varied load — <name>
    When the user adds 1 "widget" to the cart with <ms>ms latency
    Then the cart contains 1 items

    Examples:
      | name        | ms   |
      | snappy      | 30   |
      | normal      | 120  |
      | spinner     | 350  |
      | slow-disk   | 800  |
      | retry-storm | 1500 |

  # Multi-step scenario — exercises the per-failed-scenario flowchart
  # in the report. Most steps pass; the payment step fails post-upgrade
  # so the flowchart shows green-green-green-green-RED-gray.
  @migration @checkout
  Scenario: Checkout flow — payment fails post-upgrade
    When the user adds 2 "widget" to the cart
    And the user applies discount code "FLASH50"
    And the user starts checkout
    And the payment is processed
    Then the order is confirmed
