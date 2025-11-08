require "csv"

class PropertyBatchCreateService
  class InvalidCSVFormatError < StandardError; end

  HEADER_MAPPINGS = {
    "ユニークID" => "custom_unique_id",
    "物件名" => "name",
    "住所" => "address",
    "部屋番号" => "room_number",
    "賃料" => "rent_fee",
    "広さ" => "size",
    "建物の種類" => "category"
  }.freeze

  BATCH_SIZE = 1000

  attr_reader :result, :status

  def initialize(file)
    @file = file

    @status = nil
    @processed_count = 0
    @invalid_data = []
    @result = {}
    @batch = []
    @row_number = 0
  end

  def call
    validate_file!
    process_csv

    @result = {
      records_processed: @processed_count,
      invalid_data: @invalid_data
    }
    self
  rescue InvalidCSVFormatError, CSV::MalformedCSVError => e
    @status = :bad_request
    @result = { error: e }
    self
  rescue StandardError => e
    @status = :internal_server_error
    @result = { error: e }
    self
  end

  def completed?
    @status == :completed
  end

  private

  def validate_file!
    raise InvalidCSVFormatError, "No file provided" unless @file.present?
    unless @file.content_type == "text/csv" || @file.original_filename&.end_with?(".csv")
      raise InvalidCSVFormatError, "File must be a CSV file"
    end
  end

  def process_csv
    file_path = @file.tempfile.path

    # Read first row to validate headers
    first_row = true
    CSV.foreach(file_path, headers: true) do |row|
      @row_number += 1

      if first_row
        validate_headers!(row.headers)
        first_row = false
      end

      process_row(row)
    end

    # Insert any remaining records in the batch
    flush_batch

    @status = :completed
  end

  def validate_headers!(csv_headers)
    missing_headers = HEADER_MAPPINGS.keys - csv_headers
    if missing_headers.any?
      raise InvalidCSVFormatError, "Missing required headers: #{missing_headers.join(', ')}"
    end
  end

  def process_row(row)
    attributes = map_row_to_attributes(row)
    current_row_number = @row_number

    # Validate attributes before adding to batch
    property = Property.new(attributes)

    if property.valid?
      add_to_batch(attributes, current_row_number)
    else
      @invalid_data << { row: current_row_number, error: property.errors.full_messages.join(", ") }
    end
  end

  def add_to_batch(attributes, row_number)
    now = Time.current
    @batch << {
      attributes: attributes.merge(
        id: SecureRandom.uuid,
        created_at: now,
        updated_at: now
      ),
      row_number: row_number
    }

    if @batch.size >= BATCH_SIZE
      flush_batch
    end
  end

  def flush_batch
    return if @batch.empty?

    attributes_array = @batch.map { |item| item[:attributes] }

    Property.upsert_all(
      attributes_array,
      unique_by: :custom_unique_id,
      update_only: [ :name, :address, :room_number, :rent_fee, :size, :category, :updated_at ]
    )
    @processed_count += @batch.size
    @batch = []
  end

  def map_row_to_attributes(row)
    attributes = {}

    HEADER_MAPPINGS.each do |japanese_header, attribute_name|
      value = row[japanese_header]

      case attribute_name
      when "custom_unique_id"
        attributes[attribute_name] = (value.nil? || value.to_s.strip.empty?) ? nil : value.to_i
      when "rent_fee", "room_number", "size"
        # value can be nil/empty
        attributes[attribute_name] = (value.nil? || value.to_s.strip.empty?) ? nil : value.to_f
      when "name", "address", "category"
        attributes[attribute_name] = value
      end
    end

    attributes
  end
end
