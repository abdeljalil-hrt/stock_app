class AddOwnerToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :owner, :boolean, null: false, default: false
    User.order(:id).limit(1).update_all(owner: true)
  end

  def down
    remove_column :users, :owner
  end
end
