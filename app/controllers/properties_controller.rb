class PropertiesController < ApplicationController
  def index
  end

  def batch
    service = PropertyBatchCreateService.new(params[:file])
    service.call

    if service.completed?
      handle_completed_response(service)
    else
      handle_uncompleted_response(service)
    end
  end

  private

  def handle_uncompleted_response(service)
    error = service.result[:error]
    status = service.status

    error_message = case status
    when :bad_request
      "Invalid CSV Format: #{error.message }"
    when :internal_server_error
      "Interval Server Error: #{error.message}"
    end

    respond_to do |format|
      format.html do
        flash[:alert] = error_message
        redirect_to properties_path
      end
    end
  end

  def handle_completed_response(service)
    records_processed = service.result[:records_processed]
    invalid_data = service.result[:invalid_data]
    message = "Batch processing completed (records created or updated).\nProcessed records: #{records_processed}"

    respond_to do |format|
      format.html do
        flash[:notice] = message
        flash[:invalid_data] = invalid_data unless invalid_data.empty?
        redirect_to properties_path
      end
    end
  end
end
