# How I Developed the Application with AI Tools

1. **Planned the development flow** - Identified and prioritized the required components (e.g., `1. Endpoints`, `2. Properties table`, etc.)
2. **Documented technical details** - Wrote down specific implementation requirements and broke them into subtasks
3. **Iterative implementation** - Asked the AI to implement each task one by one, then reviewed and fixed the generated code as needed

---
# Used Prompts
## Features
### 1. Endpoints
- Add an endpoint `POST /properties/batch` to handle the request with CSV file
- Add a property index page with a data form to upload csv file to `POST /properties/batch` endpoint

### 2. Properties table
- Add a migration file to create a `properties` table with columns:
```
id: uuid (PK)
custom_unique_id: integer, unnullable
name: string, unnullable
address: string, unnullable
room_number: integer, nullable
rent_fee: integer, nullable
size: float, nullable
category: string, unnullable
```
and with index on `[category]` and unique index on `[custom_unique_id]`

### 3. CSV file handling service
- Create a new service `proerty_batch_create_service` to migrate the current CSV file processing in batch creating controller. 
- The validation of the service would return a custom validation error, `InvalidCSVFormatError` if validation failed.
- Batch create the property records (1000 records once) instead of creating them one by one.
- Create or update the property records based on `custom_unique_id`
- Only allow `アパート`、`一戸建て`、`マンション` values in `category` column
- room_number is allowed to be null only when the category is `一戸建て`

### 4. Validation message in Japanese
- Support validation message of property model in janapense

## Tests
- Add tests to test `proerty_batch_create_service` with customized temp csv file
- Write tests to test `POST properties/batch` endpoint
