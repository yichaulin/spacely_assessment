RSpec.describe "POST /properties/batch", type: :request do
  let(:mock_service) { instance_double(PropertyBatchCreateService) }
  let(:file) { fixture_file_upload('test.csv', 'text/csv') }

  before do
    allow(PropertyBatchCreateService).to receive(:new).and_return(mock_service)
    allow(mock_service).to receive(:call)
  end

  describe "Successful batch processing" do
    let(:records_processed) { 10 }
    let(:invalid_data) { [] }
    before do
      allow(mock_service).to receive(:completed?).and_return(true)
      allow(mock_service).to receive(:result).and_return({
        records_processed: records_processed,
        invalid_data: invalid_data
      })
    end

    context "HTML format" do
      it "redirects to properties path with success flash message" do
        post batch_properties_path, params: { file: file }

        expect(response).to redirect_to(properties_path)
        expect(flash[:notice]).to include("Batch processing completed")
        expect(flash[:notice]).to include("Processed records: 10")
      end

      it "includes invalid data in flash when present" do
        allow(mock_service).to receive(:result).and_return({
          records_processed: 8,
          invalid_data: [
            { row: 5, error: "Name can't be blank" },
            { row: 7, error: "Address can't be blank" }
          ]
        })

        post batch_properties_path, params: { file: file }

        expect(flash[:invalid_data]).to be_present
        expect(flash[:invalid_data].size).to eq(2)
      end

      it "does not include invalid_data flash when empty" do
        post batch_properties_path, params: { file: file }

        expect(flash[:invalid_data]).to be_nil
      end
    end
  end

  describe "Bad request errors" do
    let(:error) { PropertyBatchCreateService::InvalidCSVFormatError.new("File must be a CSV file") }

    before do
      allow(mock_service).to receive(:completed?).and_return(false)
      allow(mock_service).to receive(:status).and_return(:bad_request)
      allow(mock_service).to receive(:result).and_return({ error: error })
    end

    context "HTML format" do
      it "redirects to properties path with error flash message" do
        post batch_properties_path, params: { file: file }

        expect(response).to redirect_to(properties_path)
        expect(flash[:alert]).to eq("Invalid CSV Format: File must be a CSV file")
      end
    end
  end

  describe "Internal server errors" do
    let(:error) { StandardError.new("Database connection failed") }

    before do
      allow(mock_service).to receive(:completed?).and_return(false)
      allow(mock_service).to receive(:status).and_return(:internal_server_error)
      allow(mock_service).to receive(:result).and_return({ error: error })
    end

    context "HTML format" do
      it "redirects to properties path with error flash message" do
        post batch_properties_path, params: { file: file }

        expect(response).to redirect_to(properties_path)
        expect(flash[:alert]).to eq("Interval Server Error: Database connection failed")
      end
    end
  end
end
