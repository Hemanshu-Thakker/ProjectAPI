Rails.application.routes.draw do
  get '/get_measurables' => 'measurables#get_measurable'
  post '/post_measurables' => 'measurables#post_measurable'
end
