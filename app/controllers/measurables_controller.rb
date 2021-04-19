class MeasurablesController < ApplicationController
	before_action :jwt_decode, only: [:post_measurable]
	def get_measurable
		@data = BankingInfo.last.json
	  	render json: @data, status: 200
	end
	def post_measurable
		BankingInfo.last.update(json: @json_body)
		render json: {}, status: 200
	end
end
