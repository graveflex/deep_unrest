class CreateActivities < ActiveRecord::Migration[5.2]
  def change
    create_table :activities do |t|
      t.references :user, polymorphic: true, index: true
      t.references :target, polymorphic: true, index: true
      t.string :log_message
      t.timestamps
    end
  end
end
