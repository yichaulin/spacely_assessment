class PropertiesController < ApplicationController
  def index
  end

  def batch
    unless params[:file].present?
      respond_to do |format|
        format.json { render json: { error: "No file provided" }, status: :bad_request }
        format.html do
          flash[:alert] = "No file provided"
          redirect_to properties_path
        end
      end
      return
    end

    begin
      csv_file = params[:file]
      
      unless csv_file.content_type == 'text/csv' || csv_file.original_filename.end_with?('.csv')
        respond_to do |format|
          format.json { render json: { error: "File must be a CSV file" }, status: :bad_request }
          format.html do
            flash[:alert] = "File must be a CSV file"
            redirect_to properties_path
          end
        end
        return
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
      
      respond_to do |format|
        format.json { render json: response_data, status: :ok }
        format.html do
          if errors.any?
            flash[:alert] = "Processed #{processed_count} records with #{errors.count} errors."
            flash[:errors] = errors
          else
            flash[:notice] = "Successfully processed #{processed_count} records."
          end
          redirect_to properties_path
        end
      end
    rescue CSV::MalformedCSVError => e
      respond_to do |format|
        format.json { render json: { error: "Invalid CSV format: #{e.message}" }, status: :bad_request }
        format.html do
          flash[:alert] = "Invalid CSV format: #{e.message}"
          redirect_to properties_path
        end
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { error: "Error processing file: #{e.message}" }, status: :internal_server_error }
        format.html do
          flash[:alert] = "Error processing file: #{e.message}"
          redirect_to properties_path
        end
      end
    end
  end
end

