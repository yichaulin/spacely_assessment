RSpec.describe PropertyBatchCreateService, type: :service do
  describe "#call" do
    let(:service) { described_class.new(uploaded_file) }
    let(:tempfile) do
      file = Tempfile.new([ "test", ".csv" ])
      file.write(csv_data)
      file.rewind
      file
    end

    let(:uploaded_file) do
      ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: "test.csv",
        type: "text/csv"
      )
    end

    after do
      tempfile.close
      tempfile.unlink
    end

    context "With valid CSV file" do
      context "When all records are valid" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,テスト物件1,東京都テスト区1-1-1,101,100000,30,マンション
            2,テスト物件2,東京都テスト区1-1-2,102,120000,40,アパート
          CSV
        end
        it "creates all records" do
          service.call
          expect(service).to be_completed
          expect(service.result[:records_processed]).to eq(2)
          expect(service.result[:invalid_data]).to be_empty

          expect(Property.count).to eq(2)
          expect(Property.exists?(custom_unique_id: 1)).to be_truthy
          expect(Property.exists?(custom_unique_id: 2)).to be_truthy
        end
      end

      context "When some records are invalid" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,テスト物件1,東京都テスト区1-1-1,101,100000,30,マンション
            2,,東京都テスト区1-1-2,102,120000,40,アパート
          CSV
        end
        it "creates valid records and handles invalid records error" do
          service.call
          expect(service).to be_completed
          expect(service.result[:records_processed]).to eq(1)
          expect(service.result[:invalid_data].size).to eq(1)
          expect(service.result[:invalid_data].first[:error]).to include("Name can't be blank")

          expect(Property.count).to eq(1)
          expect(Property.exists?(custom_unique_id: 1)).to be_truthy
          expect(Property.exists?(custom_unique_id: 2)).to be_falsey
        end
      end
    end

    context "With invalid file" do
      context "When file is not CSV" do
        let(:tempfile) do
          file = Tempfile.new([ "test", ".txt" ])
          file.write("invalid file")
          file.rewind
          file
        end

        let(:uploaded_file) do
          ActionDispatch::Http::UploadedFile.new(
            tempfile: tempfile,
            filename: "test.txt",
            type: "text/plain"
          )
        end

        it "does not process file and service status is bad_request" do
          service.call
          expect(service.status).to eq(:bad_request)
          expect(service.result[:error].is_a?(PropertyBatchCreateService::InvalidCSVFormatError))
        end
      end

      context "When file is CSV but headers are missing" do
        let(:csv_data) do
          <<~CSV
            1,テスト物件1,東京都テスト区1-1-1,101,100000,30,マンション
            2,テスト物件2,東京都テスト区1-1-2,102,120000,40,アパート
          CSV
        end
        it do
          service.call
          expect(service.status).to eq(:bad_request)
          expect(service.result[:error].is_a?(PropertyBatchCreateService::InvalidCSVFormatError))
        end
      end
    end

    context "Record overriding (upsert behavior)" do
      context "When a record with the same custom_unique_id already exists" do
        let!(:existing_property) do
          Property.create!(
            id: SecureRandom.uuid,
            custom_unique_id: 1,
            name: "Old Property Name",
            address: "Old Address",
            room_number: 999,
            rent_fee: 50000,
            size: 20,
            category: "マンション",
            created_at: '2025-10-10 00:00:00',
            updated_at: '2025-10-10 00:00:00'
          )
        end

        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,Updated Property Name,Updated Address,101,100000,30,マンション
          CSV
        end

        let(:current) { Time.new(2025, 10, 11, 0, 0, 0) }

        it "updates the existing record instead of creating a new one" do
          Timecop.freeze(current) do
            service.call
          end

          expect(service).to be_completed
          expect(service.result[:records_processed]).to eq(1)
          expect(Property.count).to eq(1)

          updated_property = Property.find_by(custom_unique_id: 1)
          expect(updated_property.id).to eq(existing_property.id)
          expect(updated_property.name).to eq("Updated Property Name")
          expect(updated_property.address).to eq("Updated Address")
          expect(updated_property.room_number).to eq(101)
          expect(updated_property.rent_fee).to eq(100000)
          expect(updated_property.size).to eq(30)
          expect(updated_property.category).to eq("マンション")
          expect(updated_property.updated_at).to eq(current)
        end
      end

      context "When the same custom_unique_id appears multiple times in CSV" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,First Version,First Address,101,100000,30,マンション
            1,Second Version,Second Address,102,120000,40,アパート
          CSV
        end

        it "processes both records and the last one wins" do
          service.call
          expect(service).to be_completed
          expect(service.result[:records_processed]).to eq(2)
          expect(Property.count).to eq(1)

          final_property = Property.find_by(custom_unique_id: 1)
          expect(final_property.name).to eq("Second Version")
          expect(final_property.address).to eq("Second Address")
          expect(final_property.room_number).to eq(102)
        end
      end
    end

    context "Record validation" do
      shared_examples "handle validation with expected invalid message" do
        it do
          service.call
          expect(service).to be_completed
          expect(service.result[:invalid_data].size).to eq(1)
          expect(service.result[:invalid_data].first[:error]).to include(invalid_message)
        end
      end
      context "When ユニークID is empty" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            ,テスト物件1,東京都テスト区1-1-1,101,100000,30,マンション
          CSV
        end
        let(:invalid_message) { "Custom unique can't be blank" }

        it_behaves_like "handle validation with expected invalid message"
      end
      context "When 物件名 is empty" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,,東京都テスト区1-1-1,101,100000,30,マンション
          CSV
        end
        let(:invalid_message) { "Name can't be blank" }

        it_behaves_like "handle validation with expected invalid message"
      end

      context "When 住所 is empty" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,テスト物件1,,101,100000,30,マンション
          CSV
        end
        let(:invalid_message) { "Address can't be blank" }

        it_behaves_like "handle validation with expected invalid message"
      end

      context "When 建物の種類 is マンション but 部屋番号 is empty" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,テスト物件1,東京都テスト区1-1-1,,100000,30,マンション
          CSV
        end
        let(:invalid_message) { "Room number is required for マンション" }

        it_behaves_like "handle validation with expected invalid message"
      end

      context "When 建物の種類 is アパート but 部屋番号 is empty" do
        let(:csv_data) do
          <<~CSV
            ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
            1,テスト物件1,東京都テスト区1-1-1,,100000,30,アパート
          CSV
        end
        let(:invalid_message) { "Room number is required for アパート" }

        it_behaves_like "handle validation with expected invalid message"
      end
    end
  end
end
