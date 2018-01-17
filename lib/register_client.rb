require 'rest-client'
require 'json'

module RegistersClient
  class RegisterClient
    def initialize(register, phase, data_store, page_size)
      @register = register
      @phase = phase
      @data_store = data_store
      @page_size = page_size

      @user_entry_number = 0
      @system_entry_number = 0

      refresh_data
    end

    def get_item(item_hash)
      @data_store.get_item(item_hash)
    end

    def get_items
      @data_store.get_items
    end

    def get_entry(entry_number)
      @data_store.get_entry(:user, entry_number)
    end

    def get_entries(since_entry_number = 0)
      EntryCollection.new(get_entries_subset_for_entry_type(since_entry_number, :user), @page_size)
    end

    def get_record(key)
      @data_store.get_record(:user, key)
    end

    def get_records
      @data_store.get_records(:user)
    end

    def get_metadata_records
      @data_store.get_records(:system)
    end

    def get_field_definitions
      ordered_fields = get_register_definition.item.value['fields']
      ordered_records = ordered_fields.map { |f| get_metadata_records.find { |record| record.entry.key == "field:#{f}" } }
      @field_definitions ||= RecordCollection.new(ordered_records, @page_size)
      @field_definitions
    end

    def get_register_definition
      get_metadata_records.select { |record| record.entry.key.start_with?('register:') }.first
    end

    def get_custodian
      get_metadata_records.select { |record| record.entry.key == 'custodian'}.first
    end

    def get_records_with_history(since_entry_number = 0)
      records_with_history = get_records_with_history_for_entry_type(since_entry_number, :user)

      RecordMapCollection.new(records_with_history, @page_size)
    end

    def get_metadata_records_with_history(since_entry_number = 0)
      metadata_records_with_history = get_records_with_history_for_entry_type(since_entry_number, :system)

      RecordMapCollection.new(metadata_records_with_history, @page_size)
    end

    def get_current_records
      RecordCollection.new(get_records.select { |record| !record.item.has_end_date }, @page_size)
    end

    def get_expired_records
      RecordCollection.new(get_records.select { |record| record.item.has_end_date }, @page_size)
    end

    def refresh_data
      latest_entry_number = @data_store.get_latest_entry_number(:user)
      rsf = download_rsf(@register, @phase, latest_entry_number)
      update_data_from_rsf(rsf, @data_store)
    end

    private

    def get_entries_subset_for_entry_type(since_entry_number, entry_type)
      start_index = !since_entry_number.nil? && since_entry_number > 0 ? since_entry_number : 0
      current_entry_number = @data_store.get_latest_entry_number(entry_type)
      length = current_entry_number - start_index

      @data_store.get_entries(entry_type).to_a.slice(start_index, length)
    end

    def get_records_with_history_for_entry_type(since_entry_number, entry_type)
      records_with_history = {}

      get_entries_subset_for_entry_type(since_entry_number, entry_type).each do |entry|
        if (!records_with_history.key?(entry.key))
          records_with_history[entry.key] = []
        end

        item = @data_store.get_item(entry.item_hash)
        records_with_history[entry.key] << Record.new(entry, item)
      end

      records_with_history
    end

    def download_rsf(register, phase, start_entry_number)
      RestClient.get("https://#{register}.#{phase}.openregister.org/download-rsf/#{start_entry_number}")
    end

    def update_data_from_rsf(rsf, data_store)
      rsf.each_line do |line|
        line.slice!("\n")
        params = line.split("\t")
        command = params[0]

        if command == 'add-item'
          data_store.add_item(RegistersClient::Item.new(line))
        elsif command == 'append-entry'
          if params[1] == 'user'
            @user_entry_number += 1

            entry = Entry.new(line, @user_entry_number, params[1])
          else
            @system_entry_number += 1

            entry = Entry.new(line, @system_entry_number, params[1])
          end

          data_store.append_entry(entry)
        end
      end

      data_store.after_load
    end
  end
end