class AddActiveToApplicant < ActiveRecord::Migration[5.1]
  def change
    add_column :applicants, :active, :boolean, default: true
  end
end
