class PropertiesController < ApplicationController
  # TODO: Remove this once the page of file uploading form is implemented
  skip_before_action :verify_authenticity_token

  def batch
    unless params[:file].present?
      return render json: { error: "No file provided" }, status: :bad_request
    end

    begin
      csv_file = params[:file]
      
      unless csv_file.content_type == 'text/csv' || csv_file.original_filename.end_with?('.csv')
        return render json: { error: "File must be a CSV file" }, status: :bad_request
      end

      # Process CSV file line by line
      processed_count = 0
      errors = []
      
      file_path = csv_file.tempfile.path
      CSV.foreach(file_path, headers: true) do |row|
        begin
          # Process each row
          # TODO: Implement your batch processing logic here
          # Example: Property.create(row.to_h)
          
          processed_count += 1
        rescue => e
          errors << { row: processed_count + 1, error: e.message }
        end
      end
      
      response_data = {
        message: "Batch processing completed",
        records_processed: processed_count
      }
      
      response_data[:errors] = errors if errors.any?
      
      render json: response_data, status: :ok
    rescue CSV::MalformedCSVError => e
      render json: { error: "Invalid CSV format: #{e.message}" }, status: :bad_request
    rescue => e
      render json: { error: "Error processing file: #{e.message}" }, status: :internal_server_error
    end
  end
end

