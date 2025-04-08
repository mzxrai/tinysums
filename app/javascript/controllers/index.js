// Import the application for Stimulus from within the controllers directory
import { application } from "./application"

// Import controllers
import ClickableRowController from "./clickable_row_controller"

// Register each controller manually
application.register("clickable-row", ClickableRowController) 