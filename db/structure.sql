CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "properties" ("id" uuid NOT NULL PRIMARY KEY, "custom_unique_id" integer NOT NULL, "name" varchar NOT NULL, "address" varchar NOT NULL, "category" varchar NOT NULL, "room_number" integer, "rent_fee" integer, "size" float, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_properties_on_custom_unique_id" ON "properties" ("custom_unique_id") /*application='SpacelyAssessment'*/;
CREATE INDEX "index_properties_on_category" ON "properties" ("category") /*application='SpacelyAssessment'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20251108050517');

