# frozen_string_literal: true

# Provides authentication helpers for RSpec tests
# These helpers make it easier to authenticate requests in tests
module AuthHelpers
  # Sets up authentication for a user in a controller test
  #
  # @param user [User] The user to authenticate as
  def authenticate_user(user)
    # TODO: Implement authentication
  end
end

RSpec.configure do |config|
  # config.include AuthHelpers, type: :tbd
end