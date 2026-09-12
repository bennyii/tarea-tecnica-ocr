class ApplicationRecord < ActiveRecord::Base
  # Shared base class for all Active Record models in the application.
  # Keeping this as an abstract model ensures common behavior is centralized and consistent.
  primary_abstract_class
end
