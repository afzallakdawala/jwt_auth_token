require 'jwt'
require 'rest-client'
require 'csv'

module JwtAuthToken

  def jwt_hmac_secret
    @_jwt_hmac_secret ||= Rails.application.secrets[:secret_key_base]
  end

  def jwt_algorithm
    @_jwt_algorithm ||= 'HS512'
  end

  def jwt_set_header(data)
    encoded_token = JWT.encode(data,jwt_hmac_secret,jwt_algorithm)
    response.set_header(jwt_header_name, encoded_token)
  end

  def jwt_header_name
    @_jwt_header_name ||= "embibe-token"
  end

  def jwt_header_token
    @_jwt_header_token ||= request.headers[jwt_header_name] rescue nil
  end

  def is_jwt_valid_token?
    begin
      @decoded_token = JSON.parse(JWT.decode(jwt_header_token, jwt_hmac_secret, true, { :algorithm => jwt_algorithm })[0])
      return validate_keys
    rescue Exception => e
      return false
    end  
  end

end

include JwtAuthToken, UserHelper, RouterHelper, CommonHelper
generate_third_party_url
