class CreateSurveys < ActiveRecord::Migration[5.0]
  def change
    create_table :surveys do |t|
      t.string :name
      t.references :applicant, foreign_key: true

      t.timestamps
    end
  end
end
