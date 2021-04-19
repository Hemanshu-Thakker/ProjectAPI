class CreateBankingInfos < ActiveRecord::Migration[6.0]
  def change
    create_table :banking_infos do |t|
    	t.json :json
     	t.timestamps
    end
  end
end
