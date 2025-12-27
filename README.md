# Vezor Ruby SDK

A Ruby SDK for interacting with the Vezor secrets management platform.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vezor'
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install vezor
```

## Quick Start

```ruby
require 'vezor'

client = Vezor::Client.new(
  base_url: "https://api.vezor.io",
  token: "your-api-token",
  organization_id: "your-org-uuid"
)

# List all secrets
result = client.list_secrets
result["secrets"].each do |secret|
  puts "#{secret['key_name']}: #{secret['tags']}"
end

# Get a secret by name
secret = client.get_secret_by_name("DATABASE_URL", tags: { env: "prod" })
puts secret["value"] if secret

# Create a new secret
client.create_secret(
  key_name: "API_KEY",
  value: "sk-live-xxx",
  tags: { env: "prod", app: "api" },
  description: "Stripe API key"
)
```

## Authentication

### Direct initialization

```ruby
client = Vezor::Client.new(
  base_url: "https://api.vezor.io",
  token: "your-api-token",
  organization_id: "your-org-uuid"
)
```

### Using environment variables

```ruby
# Set these environment variables:
# VEZOR_API_URL=https://api.vezor.io
# VEZOR_TOKEN=your-api-token
# VEZOR_ORGANIZATION_ID=your-org-uuid

client = Vezor.client
```

### Update credentials after initialization

```ruby
client = Vezor::Client.new(base_url: "https://api.vezor.io")
client.token = "your-api-token"
client.organization_id = "your-org-uuid"
```

## Core Operations

### Listing Secrets

```ruby
# List all secrets
result = client.list_secrets

# Filter by tags
result = client.list_secrets(tags: { env: "prod", app: "api" })

# Search by key name
result = client.list_secrets(search: "DATABASE")

# Pagination
result = client.list_secrets(limit: 10, offset: 0)

# Combined
result = client.list_secrets(
  tags: { env: "prod" },
  search: "API",
  limit: 25,
  offset: 0
)

# Response structure
puts result["secrets"]  # Array of secret objects
puts result["total"]    # Total matching secrets
puts result["count"]    # Secrets in this page
```

### Getting Secrets

```ruby
# Get by ID
secret = client.get_secret("secret-uuid")
puts secret["value"]

# Get a specific version
old_secret = client.get_secret("secret-uuid", version: 2)

# Get by name (convenience method)
secret = client.get_secret_by_name("DATABASE_URL", tags: { env: "prod" })
```

### Creating Secrets

```ruby
client.create_secret(
  key_name: "DATABASE_URL",
  value: "postgres://user:pass@host:5432/db",
  tags: { env: "prod", app: "api", team: "backend" },
  description: "Production PostgreSQL connection string",
  value_type: "connection_string"  # string, password, url, connection_string
)
```

### Updating Secrets

```ruby
# Update value (creates a new version)
client.update_secret("secret-uuid", value: "new-password")

# Update description
client.update_secret("secret-uuid", description: "Updated description")

# Update tags
client.update_secret("secret-uuid", tags: { env: "prod", app: "api-v2" })
```

### Deleting Secrets

```ruby
client.delete_secret("secret-uuid")
```

### Version History

```ruby
# Get all versions
versions = client.get_secret_versions("secret-uuid")
versions["versions"].each do |v|
  puts "v#{v['version']} - #{v['created_at']} by #{v['created_by']}"
end

# Get a specific version's value
old_value = client.get_secret("secret-uuid", version: 2)
```

## Tags

```ruby
# Get all available tags
tags = client.get_tags
# { "env" => ["dev", "staging", "prod"], "app" => ["api", "web"] }

# Filter secrets by tags
prod_secrets = client.list_secrets(tags: { env: "prod" })
api_secrets = client.list_secrets(tags: { env: "prod", app: "api" })
```

## Groups

```ruby
# List all groups
groups = client.list_groups

# Get a specific group
group = client.get_group("production-api")

# Get secret count for a group
count = client.get_group_secret_count("production-api")

# Pull all secrets for a group
secrets = client.pull_group_secrets("production-api")
secrets["secrets"].each { |key, value| puts "#{key}=#{value}" }

# Export as .env format
env_content = client.pull_group_secrets("production-api", format: "env")
```

## Import/Export

```ruby
# Export secrets as .env format
env_content = client.export_env(tags: { env: "prod", app: "api" })
File.write(".env.prod", env_content)

# Import from .env file
content = File.read(".env.local")
client.import_env("development", content)
```

## Organizations

```ruby
# List your organizations
orgs = client.list_organizations
orgs["organizations"].each do |org|
  puts "#{org['name']} (#{org['id']})"
end

# Get organization details
org = client.get_organization("org-uuid")

# Create a new organization
new_org = client.create_organization(
  name: "My Team",
  description: "Development team secrets"
)
```

## Schema Validation

```ruby
schema = <<~YAML
  version: 1
  project: my-app

  base:
    database_url:
      type: connection_string
      required: true
    api_key:
      type: password
      required: true
YAML

result = client.validate_schema(schema, environment: "production")
if result["valid"]
  puts "All secrets present!"
else
  puts "Missing secrets: #{result['missing']}"
end
```

## Audit Log

```ruby
# Get recent audit entries
audit = client.get_audit_log(limit: 50)
audit["entries"].each do |entry|
  puts "#{entry['timestamp']} - #{entry['action']} - #{entry['user_email']}"
end
```

## Error Handling

The SDK provides specific exception classes for different error types:

```ruby
require 'vezor'

client = Vezor::Client.new(
  base_url: "https://api.vezor.io",
  token: "your-token",
  organization_id: "your-org"
)

begin
  secret = client.get_secret("non-existent-id")
rescue Vezor::AuthError
  puts "Authentication failed - check your token"
rescue Vezor::NotFoundError
  puts "Secret not found"
rescue Vezor::PermissionError
  puts "You don't have access to this secret"
rescue Vezor::ValidationError => e
  puts "Invalid request: #{e.message}"
rescue Vezor::APIError => e
  puts "API error #{e.status_code}: #{e.message}"
rescue Vezor::Error => e
  puts "General error: #{e.message}"
end
```

## Use Cases

### Rails Integration

```ruby
# config/initializers/vezor.rb
Vezor.default_base_url = ENV['VEZOR_API_URL']
Vezor.default_token = ENV['VEZOR_TOKEN']
Vezor.default_organization_id = ENV['VEZOR_ORGANIZATION_ID']

# Anywhere in your app
client = Vezor.client
secret = client.get_secret_by_name("STRIPE_SECRET_KEY", tags: { env: Rails.env })
```

### Local Development Setup

```ruby
#!/usr/bin/env ruby
require 'vezor'

def setup_local_env
  client = Vezor::Client.new(
    base_url: "https://api.vezor.io",
    token: ENV['VEZOR_TOKEN'],
    organization_id: "your-org-uuid"
  )

  # Get development secrets
  env_content = client.export_env(tags: { env: "dev" })
  File.write(".env", env_content)

  puts "Development environment configured!"
end

setup_local_env
```

### Secret Rotation Script

```ruby
require 'vezor'
require 'securerandom'

def rotate_api_key(client, key_name, env)
  # Find existing secret
  secret = client.get_secret_by_name(key_name, tags: { env: env })

  unless secret
    puts "Secret #{key_name} not found"
    return
  end

  # Generate new value
  new_key = SecureRandom.urlsafe_base64(32)

  # Update (creates new version, preserves history)
  client.update_secret(secret["id"], value: new_key)

  puts "Rotated #{key_name} - new version: #{secret['version'] + 1}"
  new_key
end

# Usage
client = Vezor::Client.new(...)
new_key = rotate_api_key(client, "API_SECRET_KEY", "prod")
```

### CI/CD Pipeline

```ruby
#!/usr/bin/env ruby
require 'vezor'

client = Vezor::Client.new(
  base_url: ENV['VEZOR_API_URL'],
  token: ENV['VEZOR_TOKEN'],
  organization_id: ENV['VEZOR_ORG_ID']
)

# Pull production secrets and write to .env
env_content = client.export_env(tags: { env: "prod", app: "api" })
File.write(".env", env_content)

puts "Secrets loaded for deployment"
```

## API Reference

| Method | Description |
|--------|-------------|
| `list_secrets(tags:, search:, limit:, offset:)` | List secrets with filtering |
| `get_secret(id, version:)` | Get secret by ID |
| `get_secret_by_name(name, tags:)` | Get secret by key name |
| `create_secret(key_name:, value:, tags:, ...)` | Create new secret |
| `update_secret(id, value:, description:, tags:)` | Update existing secret |
| `delete_secret(id)` | Delete secret |
| `get_secret_versions(id)` | Get version history |
| `get_tags` | Get available tags |
| `export_env(tags:)` | Export as .env format |
| `import_env(environment, content)` | Import from .env |
| `list_groups` | List secret groups |
| `get_group(name)` | Get group details |
| `pull_group_secrets(name, format:)` | Pull secrets by group |
| `list_organizations` | List organizations |
| `get_organization(id)` | Get organization |
| `create_organization(name:, description:)` | Create organization |
| `validate_schema(content, environment:)` | Validate schema |
| `get_audit_log(limit:, offset:)` | Get audit entries |
| `health` | Check API health |

## Requirements

- Ruby >= 2.7
- No external dependencies (uses Ruby stdlib)

## License

MIT License
