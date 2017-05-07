class CreateAttachments < ActiveRecord::Migration[5.0]
  def change
    create_table :attachments do |t|
      t.references :applicant, foreign_key: true
      t.references :answer, foreign_key: true
      t.string :file_uid
      t.string :file_name

      t.timestamps
    end
  end
end
