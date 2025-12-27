# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'cgi'

module Vezor
  # Client for interacting with the Vezor API
  #
  # @example Basic usage
  #   client = Vezor::Client.new(
  #     base_url: "https://api.vezor.io",
  #     token: "your-api-token",
  #     organization_id: "your-org-uuid"
  #   )
  #
  #   secrets = client.list_secrets(tags: { env: "prod" })
  #
  class Client
    attr_accessor :token, :organization_id

    # Initialize a new Vezor client
    #
    # @param base_url [String] Base URL of the Vezor API
    # @param token [String, nil] API authentication token
    # @param organization_id [String, nil] Organization UUID
    def initialize(base_url:, token: nil, organization_id: nil)
      @base_url = base_url.chomp('/')
      @token = token
      @organization_id = organization_id
    end

    # ============ Health ============

    # Check API health status
    #
    # @return [Hash] Health status information
    def health
      request(:get, '/api/v1/health')
    end

    # ============ Organizations ============

    # List organizations the authenticated user belongs to
    #
    # @return [Hash] Hash with 'organizations' array
    def list_organizations
      request(:get, '/api/v1/organizations')
    end

    # Get organization details by ID
    #
    # @param org_id [String] Organization UUID
    # @return [Hash] Organization details
    def get_organization(org_id)
      request(:get, "/api/v1/organizations/#{org_id}")
    end

    # Create a new organization
    #
    # @param name [String] Organization name
    # @param description [String] Optional description
    # @return [Hash] Created organization details
    def create_organization(name:, description: '')
      request(:post, '/api/v1/organizations', body: {
        name: name,
        description: description
      })
    end

    # ============ Secrets ============

    # List secrets with optional filtering, search, and pagination
    #
    # @param tags [Hash, nil] Filter by tags (e.g., { env: "prod", app: "api" })
    # @param search [String, nil] Search query for key_name
    # @param limit [Integer, nil] Maximum number of results
    # @param offset [Integer] Pagination offset
    # @return [Hash] Hash with secrets array, count, total, limit, offset
    #
    # @example
    #   result = client.list_secrets(tags: { env: "prod" }, limit: 10)
    #   result["secrets"].each { |s| puts s["key_name"] }
    def list_secrets(tags: nil, search: nil, limit: nil, offset: 0)
      params = {}
      params.merge!(tags.transform_keys(&:to_s)) if tags
      params['search'] = search if search
      params['limit'] = limit if limit
      params['offset'] = offset

      request(:get, '/api/v1/secrets', params: params)
    end

    # Get a secret by ID
    #
    # @param secret_id [String] Secret UUID
    # @param version [Integer, nil] Optional version number
    # @return [Hash] Secret details including decrypted value
    #
    # @example
    #   secret = client.get_secret("abc-123")
    #   puts secret["value"]
    #
    #   # Get specific version
    #   old_secret = client.get_secret("abc-123", version: 2)
    def get_secret(secret_id, version: nil)
      params = {}
      params['version'] = version if version

      request(:get, "/api/v1/secrets/#{secret_id}", params: params)
    end

    # Get a secret by key name and optional tags
    #
    # @param key_name [String] Secret key name (e.g., "DATABASE_URL")
    # @param tags [Hash, nil] Optional tag filters
    # @return [Hash, nil] Secret if found, nil otherwise
    #
    # @example
    #   secret = client.get_secret_by_name("DATABASE_URL", tags: { env: "prod" })
    #   puts secret["value"] if secret
    def get_secret_by_name(key_name, tags: nil)
      result = list_secrets(tags: tags, search: key_name, limit: 100)
      secret = result['secrets']&.find { |s| s['key_name'].downcase == key_name.downcase }
      return nil unless secret

      get_secret(secret['id'])
    end

    # Create a new secret
    #
    # @param key_name [String] Secret key name
    # @param value [String] Secret value
    # @param tags [Hash] Required tags (should include env and app)
    # @param description [String] Optional description
    # @param value_type [String] Type: "string", "password", "url", "connection_string"
    # @param metadata [Hash, nil] Optional metadata
    # @return [Hash] Created secret details
    #
    # @example
    #   client.create_secret(
    #     key_name: "DATABASE_URL",
    #     value: "postgres://...",
    #     tags: { env: "prod", app: "api" },
    #     description: "Production database"
    #   )
    def create_secret(key_name:, value:, tags:, description: '', value_type: 'string', metadata: nil)
      body = {
        key_name: key_name,
        value: value,
        tags: tags.transform_keys(&:to_s),
        path: key_name.downcase
      }
      body[:description] = description unless description.empty?
      body[:value_type] = value_type
      body[:metadata] = metadata if metadata

      request(:post, '/api/v1/secrets', body: body)
    end

    # Update an existing secret
    #
    # @param secret_id [String] Secret UUID
    # @param value [String, nil] New value (creates new version)
    # @param description [String, nil] New description
    # @param tags [Hash, nil] New tags
    # @return [Hash] Updated secret details
    #
    # @example
    #   client.update_secret("abc-123", value: "new-password")
    def update_secret(secret_id, value: nil, description: nil, tags: nil)
      body = {}
      body[:value] = value unless value.nil?
      body[:description] = description unless description.nil?
      body[:tags] = tags.transform_keys(&:to_s) if tags

      request(:put, "/api/v1/secrets/#{secret_id}", body: body)
    end

    # Delete a secret and all its versions
    #
    # @param secret_id [String] Secret UUID
    # @return [Hash] Deletion confirmation
    def delete_secret(secret_id)
      request(:delete, "/api/v1/secrets/#{secret_id}")
    end

    # Get version history for a secret
    #
    # @param secret_id [String] Secret UUID
    # @return [Hash] Hash with 'versions' array
    #
    # @example
    #   versions = client.get_secret_versions("abc-123")
    #   versions["versions"].each do |v|
    #     puts "v#{v['version']} by #{v['created_by']}"
    #   end
    def get_secret_versions(secret_id)
      request(:get, "/api/v1/secrets/#{secret_id}/versions")
    end

    # ============ Tags ============

    # Get available tags grouped by key
    #
    # @return [Hash] Tag keys with array of values
    #
    # @example
    #   tags = client.get_tags
    #   # { "env" => ["dev", "prod"], "app" => ["api", "web"] }
    def get_tags
      request(:get, '/api/v1/tags')
    end

    # ============ Import/Export ============

    # Export secrets as .env format
    #
    # @param tags [Hash, nil] Optional tag filters
    # @return [String] .env formatted string
    #
    # @example
    #   env_content = client.export_env(tags: { env: "prod", app: "api" })
    #   File.write(".env", env_content)
    def export_env(tags: nil)
      params = tags&.transform_keys(&:to_s) || {}
      request(:get, '/api/v1/export', params: params, raw: true)
    end

    # Import secrets from .env format
    #
    # @param environment [String] Target environment
    # @param env_content [String] .env file content
    # @return [Hash] Import results
    #
    # @example
    #   content = File.read(".env.local")
    #   client.import_env("development", content)
    def import_env(environment, env_content)
      request(:post, "/api/v1/import/#{environment}", body: env_content, content_type: 'text/plain')
    end

    # ============ Groups ============

    # List all secret groups in the organization
    #
    # @return [Hash] Hash with 'groups' array
    def list_groups
      request(:get, '/api/v1/groups')
    end

    # Get a group by name
    #
    # @param name [String] Group name
    # @return [Hash] Group details including tags
    def get_group(name)
      request(:get, "/api/v1/groups/#{CGI.escape(name)}")
    end

    # Get count of secrets matching a group's tags
    #
    # @param name [String] Group name
    # @return [Hash] Hash with 'count' field
    def get_group_secret_count(name)
      request(:get, "/api/v1/groups/#{CGI.escape(name)}/count")
    end

    # Pull all secrets matching a group's tags
    #
    # @param name [String] Group name
    # @param format [String] Output format: "json", "env", or "export"
    # @return [Hash, String] Hash for json, String for env/export
    #
    # @example
    #   secrets = client.pull_group_secrets("production-api")
    #   secrets["secrets"].each { |k, v| puts "#{k}=#{v}" }
    #
    #   env_content = client.pull_group_secrets("production-api", format: "env")
    def pull_group_secrets(name, format: 'json')
      raw = %w[env export].include?(format)
      request(:get, "/api/v1/groups/#{CGI.escape(name)}/secrets", params: { format: format }, raw: raw)
    end

    # ============ Validation ============

    # Validate a schema against stored secrets
    #
    # @param schema_content [String] YAML schema content
    # @param environment [String] Environment to validate against
    # @return [Hash] Validation results
    def validate_schema(schema_content, environment: 'development')
      request(:post, '/api/v1/validate', body: {
        schema: schema_content,
        environment: environment
      })
    end

    # ============ Audit ============

    # Get audit log entries
    #
    # @param limit [Integer] Maximum entries to return
    # @param offset [Integer] Pagination offset
    # @return [Hash] Hash with 'entries' array
    def get_audit_log(limit: 100, offset: 0)
      request(:get, '/api/v1/audit', params: { limit: limit, offset: offset })
    end

    private

    def request(method, endpoint, params: {}, body: nil, raw: false, content_type: 'application/json')
      uri = URI("#{@base_url}#{endpoint}")
      uri.query = URI.encode_www_form(params) unless params.empty?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request_class = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        put: Net::HTTP::Put,
        delete: Net::HTTP::Delete
      }[method]

      req = request_class.new(uri)
      req['User-Agent'] = "vezor-ruby/#{Vezor::VERSION}"
      req['Authorization'] = "Bearer #{@token}" if @token
      req['X-Organization-Id'] = @organization_id if @organization_id
      req['Content-Type'] = content_type

      if body
        req.body = body.is_a?(String) ? body : JSON.generate(body)
      end

      response = http.request(req)
      Vezor.raise_for_status(response)

      raw ? response.body : JSON.parse(response.body)
    end
  end
end
