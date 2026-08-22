class CreateMcpToolCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_tool_calls do |t|
      t.integer  :user_id, null: false
      t.string   :tool_name, null: false
      t.string   :argument_keys
      t.string   :target_type
      t.integer  :target_id
      t.boolean  :ok, null: false, default: true
      t.string   :error_code
      t.integer  :duration_ms
      t.datetime :created_on
    end
    add_index :mcp_tool_calls, [:user_id, :created_on]
    add_index :mcp_tool_calls, :created_on
  end
end
