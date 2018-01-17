require 'spec_helper'
require 'register_client_manager'

RSpec.describe RegistersClient::RegisterClientManager do
  describe 'get_register' do
    before(:each) do
      setup
    end

    it 'should create and return a new register client for the given register when one does not currently exist' do
      client_manager = RegistersClient::RegisterClientManager.new(@config_options)
      expect(client_manager).to receive(:create_register_client).with('country', 'test', @country_test_data_store, @page_size).once { @country_test_register_client }

      register_client = client_manager.get_register("country", "test", @country_test_data_store)

      expect(register_client).to eq(@country_test_register_client)
    end

    it 'should return the cached register client when one already exists for the given parameters' do
      client_manager = RegistersClient::RegisterClientManager.new(@config_options)
      expect(client_manager).to receive(:create_register_client).with('country', 'test', @country_test_data_store, @page_size).once { @country_test_register_client }

      register_client = client_manager.get_register("country", "test", @country_test_data_store)
      cached_register_client = client_manager.get_register("country", "test", @country_beta_data_store)

      expect(register_client).to eq(@country_test_register_client)
      expect(cached_register_client).to eq(register_client)
    end

    it 'should create multiple register clients when the given register is in multiple environments' do
      client_manager = RegistersClient::RegisterClientManager.new(@config_options)
      expect(client_manager).to receive(:create_register_client).with('country', 'test', @country_test_data_store, @page_size).once { @country_test_register_client }
      expect(client_manager).to receive(:create_register_client).with('country', 'beta', @country_beta_data_store, @page_size).once { @country_beta_register_client }

      test_register_client = client_manager.get_register("country", "test", @country_test_data_store)
      beta_register_client = client_manager.get_register("country", "beta", @country_beta_data_store)

      expect(test_register_client).to eq(@country_test_register_client)
      expect(beta_register_client).to eq(@country_beta_register_client)
    end

    it 'should create multiple register clients for different registers in the same environment' do
      client_manager = RegistersClient::RegisterClientManager.new(@config_options)
      expect(client_manager).to receive(:create_register_client).with('country', 'test', @country_test_data_store, @page_size).once { @country_test_register_client }
      expect(client_manager).to receive(:create_register_client).with('field', 'test', @field_data_store, @page_size).once { @field_test_register_client }

      country_test_register_client = client_manager.get_register("country", "test", @country_test_data_store)
      field_test_register_client = client_manager.get_register("field", "test", @field_data_store)

      expect(country_test_register_client).to eq(@country_test_register_client)
      expect(field_test_register_client).to eq(@field_test_register_client)
    end

    it 'should pass the correct data store to the register client' do
      client_manager = RegistersClient::RegisterClientManager.new(@config_options)
      data_store = RegistersClient::InMemoryDataStore.new(@config_options)

      register_client = client_manager.get_register("country", "test", data_store)

      expect(register_client.instance_variable_get('@data_store')).to eq(data_store)
    end

    it 'should create a new data store when no data store is passed in' do
      client_manager = RegistersClient::RegisterClientManager.new(@config_options)

      register_client = client_manager.get_register("country", "test")

      expect(register_client.instance_variable_get('@data_store')).to be_a(RegistersClient::InMemoryDataStore)
    end

    it 'should pass the correct page size to the register client' do
      client_manager = RegistersClient::RegisterClientManager.new({page_size: 30, cache_duration: 300 })

      register_client = client_manager.get_register("country", "test", nil)

      expect(register_client.instance_variable_get('@page_size')).to eq(30)
    end
  end

  def setup
    dir = File.dirname(__FILE__)
    country_rsf = File.read(File.join(dir, 'fixtures/country_register.rsf'))
    field_rsf = File.read(File.join(dir, 'fixtures/field_register_test.rsf'))

    allow_any_instance_of(RegistersClient::RegisterClient).to receive(:download_rsf).with("country", "test", 0).and_return(country_rsf)
    allow_any_instance_of(RegistersClient::RegisterClient).to receive(:download_rsf).with("country", "beta", 0).and_return(country_rsf)
    allow_any_instance_of(RegistersClient::RegisterClient).to receive(:download_rsf).with("field", "test", 0).and_return(field_rsf)

    @config_options = { page_size: 10, cache_duration: 60 }
    @page_size = 10
    @field_data_store = RegistersClient::InMemoryDataStore.new(@config_options)
    @country_test_data_store = RegistersClient::InMemoryDataStore.new(@config_options)
    @country_beta_data_store = RegistersClient::InMemoryDataStore.new(@config_options)

    @field_test_register_client = RegistersClient::RegisterClient.new("field", "test", @field_data_store, @page_size)
    @country_test_register_client = RegistersClient::RegisterClient.new("country", "test", @country_test_data_store, @page_size)
    @country_beta_register_client = RegistersClient::RegisterClient.new("country", "beta", @country_beta_data_store, @page_size)
  end
end