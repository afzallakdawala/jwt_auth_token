class JwtAuthToken 

  def self.set_header(response, data)
    hmac_secret = Rails.application.secrets[:secret_key_base]
    payload_data = JWT.encode(data,hmac_secret,'HS512')
    response.set_header("embibe-token", payload_data)
  end

end
