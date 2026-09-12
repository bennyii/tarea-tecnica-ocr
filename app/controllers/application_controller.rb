class ApplicationController < ActionController::Base
  # Base controller for the application.
  # It centralizes browser compatibility rules and cache invalidation behavior used across the app.

  # Restrict access to modern browsers to ensure compatibility with the app's frontend features.
  allow_browser versions: :modern

  # Invalidate cached HTML responses when the import map changes so the browser always loads the latest assets.
  stale_when_importmap_changes
end
