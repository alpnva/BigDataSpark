-- ===============================================================
-- init.sql
-- Полная очистка и пересоздание таблицы при старте контейнера
-- ===============================================================

DROP TABLE IF EXISTS mock_data CASCADE;

CREATE TABLE mock_data (
    id                      INTEGER PRIMARY KEY,
    customer_first_name     VARCHAR(255),
    customer_last_name      VARCHAR(255),
    customer_age            INTEGER,
    customer_email          VARCHAR(255),
    customer_country        VARCHAR(255),
    customer_postal_code    VARCHAR(255),
    customer_pet_type       VARCHAR(255),
    customer_pet_name       VARCHAR(255),
    customer_pet_breed      VARCHAR(255),
    
    seller_first_name       VARCHAR(255),
    seller_last_name        VARCHAR(255),
    seller_email            VARCHAR(255),
    seller_country          VARCHAR(255),
    seller_postal_code      VARCHAR(255),
    
    product_name            VARCHAR(255),
    product_category        VARCHAR(255),
    product_price           NUMERIC(10,2),
    product_quantity        INTEGER,
    
    sale_date               DATE,
    sale_customer_id        INTEGER,
    sale_seller_id          INTEGER,
    sale_product_id         INTEGER,
    sale_quantity           INTEGER,
    sale_total_price        NUMERIC(12,2),
    
    store_name              VARCHAR(255),
    store_location          VARCHAR(255),
    store_city              VARCHAR(255),
    store_state             VARCHAR(255),
    store_country           VARCHAR(255),
    store_phone             VARCHAR(255),
    store_email             VARCHAR(255),
    
    pet_category            VARCHAR(255),
    product_weight          NUMERIC(8,2),
    product_color           VARCHAR(255),
    product_size            VARCHAR(255),
    product_brand           VARCHAR(255),
    product_material        VARCHAR(255),
    product_description     TEXT,
    product_rating          NUMERIC(3,1),
    product_reviews         INTEGER,
    product_release_date    DATE,
    product_expiry_date     DATE,
    
    supplier_name           VARCHAR(255),
    supplier_contact        VARCHAR(255),
    supplier_email          VARCHAR(255),
    supplier_phone          VARCHAR(255),
    supplier_address        TEXT,
    supplier_city           VARCHAR(255),
    supplier_country        VARCHAR(255)
);

-- ===============================================================
-- Загрузка начальных данных из CSV файла
-- ===============================================================

COPY mock_data FROM '/data/merged.csv'      DELIMITER ',' CSV HEADER;

-- ===============================================================
-- Создание индексов для оптимизации будущих join-ов и фильтров
-- ===============================================================

CREATE INDEX IF NOT EXISTS idx_mock_data_customer_id  ON mock_data(sale_customer_id);
CREATE INDEX IF NOT EXISTS idx_mock_data_product_id   ON mock_data(sale_product_id);
CREATE INDEX IF NOT EXISTS idx_mock_data_seller_id    ON mock_data(sale_seller_id);
CREATE INDEX IF NOT EXISTS idx_mock_data_date         ON mock_data(sale_date);
CREATE INDEX IF NOT EXISTS idx_mock_data_store_name   ON mock_data(store_name);
