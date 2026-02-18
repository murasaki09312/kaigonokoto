class AddContractPeriodExclusionConstraint < ActiveRecord::Migration[8.0]
  CONSTRAINT_NAME = "contracts_no_overlapping_periods".freeze

  def up
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    execute <<~SQL
      ALTER TABLE contracts
      ADD CONSTRAINT #{CONSTRAINT_NAME}
      EXCLUDE USING gist (
        tenant_id WITH =,
        client_id WITH =,
        daterange(start_on, COALESCE(end_on + 1, 'infinity'::date), '[)') WITH &&
      );
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE contracts
      DROP CONSTRAINT IF EXISTS #{CONSTRAINT_NAME};
    SQL
  end
end
