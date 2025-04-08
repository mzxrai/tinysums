// Import the Controller class from the Stimulus library
import { Controller } from "@hotwired/stimulus"

// Define and export the ClickableRowController class
export default class extends Controller {
  // Define static values that the controller expects from data attributes
  static values = {
    // The URL for the discussion page, passed as a string
    discussionUrl: String
  }

  // Method triggered by a click action on the controller's element
  navigate(event) {
    // Find the closest ancestor anchor tag (<a>) starting from the clicked element
    const link = event.target.closest('a')

    // Check if the click occurred directly on or within an existing link element
    if (link) {
      // If a link was clicked, do nothing and allow the browser's default link behavior
      return;
    }

    // If the click was not on a link (i.e., on the row's background/padding),
    // navigate the browser to the discussion URL stored in the data value.
    window.location.href = this.discussionUrlValue
  }
} 