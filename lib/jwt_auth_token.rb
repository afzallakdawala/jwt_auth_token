class JwtAuthToken

  def self.set_header
    hmac_secret = Rails.application.secrets[:secret_key_base]
    response.set_header("embibe-token", JWT.encode(@resource,hmac_secret,'HS512'))
  end

end