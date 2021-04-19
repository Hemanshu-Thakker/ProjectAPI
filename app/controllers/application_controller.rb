class ApplicationController < ActionController::API
	def jwt_encode(payload, exp = 24.hours.from_now)
		payload[:exp] = exp.to_i
     	JWT.encode(payload, Rails.application.secrets.secret_key_base)
	end
	def jwt_decode
        binding.pry
		token = request.headers["token"]
     	@body = JWT.decode(token, Rails.application.secrets.secret_key_base) rescue 'error'
     	if body == 'error'
     		render json: { error: "Something went wrong, Please login again." }, status: :unauthorized
     	end
   	end
end