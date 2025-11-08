RSpec.describe "POST /properties/batch", type: :request do
  let(:tempfile) do
    file = Tempfile.new([ "test", ".csv" ])
    file.write(csv_data)
    file.rewind
    file
  end

  let(:uploaded_file) do
    Rack::Test::UploadedFile.new(tempfile.path, "text/csv", original_filename: "test.csv")
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  describe "Successful batch processing" do
    context "with all valid records" do
      let(:csv_data) do
        <<~CSV
          ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
          1,テスト物件1,東京都テスト区1-1-1,101,100000,30,マンション
          2,テスト物件2,東京都テスト区1-1-2,102,120000,40,アパート
        CSV
      end

      it "redirects to properties path with success flash message" do
        post batch_properties_path, params: { file: uploaded_file }

        expect(response).to redirect_to(properties_path)
        expect(flash[:notice]).to include("Batch processing completed")
        expect(flash[:notice]).to include("Processed records: 2")
        expect(Property.count).to eq(2)
      end

      it "does not include invalid_data flash when all records are valid" do
        post batch_properties_path, params: { file: uploaded_file }

        expect(flash[:invalid_data]).to be_nil
      end
    end

    context "with some invalid records" do
      let(:csv_data) do
        <<~CSV
          ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
          1,テスト物件1,東京都テスト区1-1-1,101,100000,30,マンション
          2,,東京都テスト区1-1-2,102,120000,40,アパート
          3,テスト物件3,東京都テスト区1-1-3,103,150000,50,マンション
        CSV
      end

      it "processes valid records and includes invalid data in flash" do
        post batch_properties_path, params: { file: uploaded_file }

        expect(response).to redirect_to(properties_path)
        expect(flash[:notice]).to include("Batch processing completed")
        expect(flash[:notice]).to include("Processed records: 2")
        expect(flash[:invalid_data]).to be_present
        expect(flash[:invalid_data].size).to eq(1)
        expect(Property.count).to eq(2)
      end
    end
  end

  describe "Bad request errors" do
    context "with invalid file format" do
      let(:tempfile) do
        file = Tempfile.new([ "test", ".txt" ])
        file.write("invalid content")
        file.rewind
        file
      end

      let(:uploaded_file) do
        Rack::Test::UploadedFile.new(tempfile.path, "text/plain", original_filename: "test.txt")
      end

      it "redirects to properties path with error flash message" do
        post batch_properties_path, params: { file: uploaded_file }

        expect(response).to redirect_to(properties_path)
        expect(flash[:alert]).to include("Invalid CSV Format")
      end
    end

    context "with missing CSV headers" do
      let(:csv_data) do
        <<~CSV
          1,テスト物件1,東京都テスト区1-1-1,101,100000,30,マンション
          2,テスト物件2,東京都テスト区1-1-2,102,120000,40,アパート
        CSV
      end

      it "redirects to properties path with error flash message" do
        post batch_properties_path, params: { file: uploaded_file }

        expect(response).to redirect_to(properties_path)
        expect(flash[:alert]).to include("Invalid CSV Format")
        expect(flash[:alert]).to include("Missing required headers")
      end
    end
  end
end
