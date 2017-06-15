class AddOptionsToQuestion < ActiveRecord::Migration[5.1]
  def change
    add_column :questions, :options, :string, array: true
  end
end
