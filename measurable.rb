require "pry"
require "redis"
require "date"
require "json"
require "jwt"
require 'net/http'
require 'rest-client'

file_pointer = File.open("statement_"+ARGV[0]+".csv")
line_array = file_pointer.readlines

class JsonWebToken
 class << self
   def encode(payload, exp = 24.hours.from_now)
     payload[:exp] = exp.to_i
     JWT.encode(payload, Rails.application.secrets.secret_key_base)
   end

   def decode(token)
     body = JWT.decode(token, Rails.application.secrets.secret_key_base)[0]
     HashWithIndifferentAccess.new body
   rescue
     nil
   end
 end
end

class Ledger
	def self.fetch_month_from_date(date1, date2)
		if Date.parse(date1).strftime("%B") == Date.parse(date2).strftime("%B")
			date_arr = date1.split("/")
			date_arr[2] = (date_arr[2].to_i + 2000).to_s
			date = date_arr.join("/")
			Date.parse(date).strftime("%B %Y")
		else
			puts "-----------------Something went wrong--------------------"
		end
	end
end

class Income < Ledger
	$income_types = {"Salary": 0.0, "Upi": 0, "Piyush": 0, "Interest": 0, "NetBanking": 0, "Others": 0}
	def initialize(narration, amount)
		@type = fetch_type_based_on_narration(narration)
		$income_types[@type.to_sym]+=amount
	end

	def fetch_type_based_on_narration(narration)
		if narration.downcase.include?("upi")
			return "Upi"
		elsif (narration.downcase.include?("ib funds transfer") and narration.downcase.include?("piyush")) or (narration.downcase.include?("tpt") and narration.downcase.include?("piyush"))
			return "Piyush"
		elsif narration.include?("CREDIT INTEREST CAPITALISED")
			return "Interest"
		elsif narration.downcase.include?("imps") or narration.downcase.include?("neft")
			return "NetBanking"
		elsif (narration.downcase.include?("salary")) or narration.downcase.include?("INTERN".downcase)
			return "Salary"
		else
			return "Others"
		end
	end

	def self.total
		$income_types.values.sum
	end
end

class Expense < Ledger
	$expense_types = {"Upi": 0.0, "DebitCard": 0.0, "Withdraw": 0.0, "Automations": 0.0, "Others": 0.0}
	def initialize(narration, amount)
		@@amount = amount
		@type = fetch_type_based_on_narration(narration)
		$expense_types[@type.to_sym]+=amount if @type.class == String
	end

	def fetch_type_based_on_narration(narration)
		if narration.downcase.include?("pos")
			$categories[:fuel]+=@@amount if narration.downcase.include?("sree annamar")
			return "DebitCard"
		elsif narration.downcase.include?("upi")
			$categories[:fuel]+=@@amount if narration.downcase.include?("petrol") or narration.downcase.include?("fuel") 
			$categories[:snooker]+=@@amount if narration.downcase.include?("snooker")
			$categories[:food_bar]+=@@amount if narration.downcase.include?("food") or narration.downcase.include?("bar") or narration.downcase.include?("daru")
			$categories[:fashion]+=@@amount if narration.downcase.include?("fashion")
			$categories[:necessity]+=@@amount if narration.downcase.include?("need")
			return "Upi"
		elsif narration.downcase.include?("nwd") or narration.downcase.include?("eaw") or narration.downcase.include?("atw")
			return "Withdraw"
		elsif narration.downcase.include?("me dc")
			return "Automations"
		elsif (narration.downcase.include?("ib funds transfer") and narration.downcase.include?("piyush")) or (narration.downcase.include?("tpt") and narration.downcase.include?("piyush"))
			investment_object = Investment.new(narration, @@amount)
		else
			return "Others"
		end
	end

	def self.total
		$expense_types.values.sum
	end
end

class Investment < Expense
	$investment_type = {"Loan": 0.0, "Stocks": 0.0, "Funds/Case": 0.0, "Bonds": 0.0, "Crypto": 0.0, "Savings": 0.0}
	def initialize(narration, amount)
		@type = "Loan"
		$investment_type[@type.to_sym]+=amount
	end

	def self.total
		$investment_type.values.sum	
	end
end

class Category
	$categories = { "snooker": 0.0, "food_bar": 0.0, "fuel": 0.0, "fashion": 0.0, "necessity": 0.0 }
end

$mainstream = Redis.new
$monthly_record = Hash.new # {"key (month)": "value {Hash}"}
month = Ledger.fetch_month_from_date(line_array.first.split(",")[3], line_array.last.split(",")[3])
summary = Hash.new # summary(local variable) which is saved in monthly record redis hash
line_array.each do |line|
	arr = line.split(",")	
	if arr[4] != "" and arr[5] == ""
		expense_object = Expense.new(arr[1].to_s, arr[4].to_f)
	elsif arr[4] == "" and arr[5] != ""
		income_object = Income.new(arr[1].to_s, arr[5].to_f)
	end
end

# {title:" ",openbalance:" ",closing:" ",netbalance:" ",data:[ income:{}, saving:{} ,expense:{} ] }
summary["title"] = "#{month}"
summary["openbalance"] = "#{(line_array.first.split(",").last.to_f - line_array.first.split(",")[5].to_f + line_array.first.split(",")[4].to_f).round(2)}"
summary["netbalance"] = "#{Income.total - Expense.total}"
summary["closing"] = "#{(line_array.last.split(",").last.to_f).round(2)}"
summary["data"] = []
summary["data"] << {"income" => $income_types}
summary["data"] << {"expense" => $expense_types}
summary["data"] << {"investment" => $investment_type}
summary["data"] << {"categorysplit" => $categories}

$monthly_record = summary
redis_summary_value = JSON.parse($mainstream.get("main_summary"))
redis_summary_value << $monthly_record if !redis_summary_value.to_s.downcase.include?(month.downcase)

$mainstream.set("main_summary", redis_summary_value.to_json)

File.write("narrations.txt", JSON.parse($mainstream.get("main_summary")))

params = {}
params[:url] = "13.235.132.207:3000/post_measurables" 
params[:method] = "POST"
params[:payload] = {json_body: JSON.parse($mainstream.get("main_summary"))}
binding.pry
res = RestClient::Request.execute(params)