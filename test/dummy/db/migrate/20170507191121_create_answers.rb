class CreateAnswers < ActiveRecord::Migration[5.0]
  def change
    create_table :answers do |t|
      t.string :value
      t.references :question, foreign_key: true
      t.references :survey, foreign_key: true
      t.references :applicant, foreign_key: true

      t.timestamps
    end
  end
end
