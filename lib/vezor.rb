# frozen_string_literal: true

require_relative 'vezor/version'
require_relative 'vezor/errors'
require_relative 'vezor/client'

# Vezor SDK - GitOps-native secrets management
#
# @example Quick start
#   require 'vezor'
#
#   client = Vezor::Client.new(
#     base_url: "https://api.vezor.io",
#     token: "your-api-token",
#     organization_id: "your-org-uuid"
#   )
#
#   # List secrets
#   secrets = client.list_secrets(tags: { env: "prod" })
#
#   # Get a secret
#   secret = client.get_secret_by_name("DATABASE_URL", tags: { env: "prod" })
#   puts secret["value"]
#
#   # Create a secret
#   client.create_secret(
#     key_name: "API_KEY",
#     value: "secret-value",
#     tags: { env: "prod", app: "api" }
#   )
#
module Vezor
  class << self
    # Configure default client settings
    attr_accessor :default_base_url, :default_token, :default_organization_id

    # Create a new client with default settings
    #
    # @return [Vezor::Client]
    def client
      Client.new(
        base_url: default_base_url || ENV['VEZOR_API_URL'] || 'https://api.vezor.io',
        token: default_token || ENV['VEZOR_TOKEN'],
        organization_id: default_organization_id || ENV['VEZOR_ORGANIZATION_ID']
      )
    end
  end
end
