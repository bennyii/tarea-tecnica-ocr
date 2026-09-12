require_relative "boot"

require "rails/all"

# Load the gems required by the current environment.
# This keeps the application configuration aligned with the active Rails environment.
Bundler.require(*Rails.groups)

module TareaTecnicaOcr
  class Application < Rails::Application
    # Inherit sensible defaults for the current Rails version.
    config.load_defaults 8.1

    # Exclude non-Ruby directories from eager loading to keep boot time and reload behavior predictable.
    config.autoload_lib(ignore: %w[assets tasks])

    # Global application configuration for the app.
    # Environment-specific overrides are defined in config/environments/*.
    #
    # Examples:
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
