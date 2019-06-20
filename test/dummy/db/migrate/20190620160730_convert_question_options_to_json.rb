class ConvertQuestionOptionsToJson < ActiveRecord::Migration[5.2]
  def change
    change_column :questions, :options, :jsonb, default: '[]'
  end
end
