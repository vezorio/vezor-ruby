# frozen_string_literal: true

module Vezor
  # Base error class for all Vezor SDK errors
  class Error < StandardError; end

  # Authentication failed or token expired (401)
  class AuthError < Error; end

  # Resource not found (404)
  class NotFoundError < Error; end

  # Validation error (400)
  class ValidationError < Error; end

  # Permission denied (403)
  class PermissionError < Error; end

  # Generic API error with status code and response details
  class APIError < Error
    attr_reader :status_code, :response

    def initialize(message, status_code: nil, response: nil)
      super(message)
      @status_code = status_code
      @response = response
    end
  end

  # Raises appropriate error based on HTTP status code
  def self.raise_for_status(response)
    return if response.is_a?(Net::HTTPSuccess)

    body = begin
      JSON.parse(response.body)
    rescue StandardError
      {}
    end

    message = body['error'] || body['message'] || response.body || "HTTP #{response.code}"

    case response.code.to_i
    when 401
      raise AuthError, message
    when 403
      raise PermissionError, message
    when 404
      raise NotFoundError, message
    when 400
      raise ValidationError, message
    else
      raise APIError.new(message, status_code: response.code.to_i, response: body)
    end
  end
end
