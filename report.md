# Анализ больших данных - Лабораторная работа №2 — ETL реализованный с помощью Spark

**Студент:** *Алапанова Эльза*
**Группа:** *М8О-209СВ-24*

---

**Цель работы:** целью данной лабораторной работы является разработка ETL-пайплайна для обработки больших данных с использованием фреймворка **Apache Spark**, построение аналитической модели данных типа *звезда / снежинка* и формирование витрин данных в различных NoSQL-хранилищах.

Вся инфраструктура разворачивается с помощью **Docker Compose** и включает следующие сервисы:

* PostgreSQL — хранение исходных данных и DWH;
* Apache Spark (master + worker);
* Jupyter Notebook — разработка ETL;
* ClickHouse — основное аналитическое хранилище;
* MongoDB, Neo4j, Valkey — дополнительные NoSQL-БД.

Общая схема обработки данных:

```
CSV → PostgreSQL → Spark → DWH → Spark → ClickHouse / NoSQL
```

### Основные компоненты

* Загрузка в `Postgres` и создание модели снежинка [Postgres.ipynb](./app/Postgres.ipynb). Раздел отчета [тут](#postgres).
* Создание и загрузка витрин в `ClickHouse` [ClickHouse.ipynb](./app/ClickHouse.ipynb). Раздел отчета [тут](#clickhouse).
* Создание и загрузка витрин в `Mongo` [Mongo.ipynb](./app/Mongo.ipynb). Раздел отчета [тут](#mongo).
* Создание и загрузка витрин в `Neo4j` [Neo4j.ipynb](./app/Neo4j.ipynb). Раздел отчета [тут](#neo4j).
* Создание и загрузка витрин в `Valkey` [Valkey.ipynb](./app/Valkey.ipynb). Раздел отчета [тут](#valkey).

---

## Ход работы

### Подготовка данных

Исходные данные представлены десятью CSV-файлами `mock_data_*.csv`, каждый из которых содержит по 1000 строк.

Для удобства загрузки был реализован скрипт [prepare_data.py](./scripts/prepare_data.py), который объединяет все файлы в единый CSV [data/merged.csv](./data/merged.csv), содержащий 10 000 записей.

### Сервисы

Запуск всех сервисов происходит через [docker-compose.yml](./docker-compose.yml). Так же созданы 2 `Dockerfile's` для работы с `Spark` сервисами: `master`, `worker`, и для сервера `Jupyter`. В них загружаются основные драйвера и клиенты для подключения к разным БД.

### Загрузка данных в PostgreSQL

При старте контейнера PostgreSQL выполняется SQL-скрипт `init.sql`, который создаёт таблицу `mock_data` и загружает данные из CSV.

```sql
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
-- MORE
```

### Чтение данных в Spark

Подключение Spark к PostgreSQL осуществляется через JDBC:

```python
# Инициализация SparkSession с драйвером PostgreSQL
spark = SparkSession.builder \
    .master("spark://spark-master:7077") \
    .appName("ETL to Star") \
    .getOrCreate()


pg_url = "jdbc:postgresql://postgres:5432/bober_db"
pg_properties = {"user": "bober", "password": "bober", "driver": "org.postgresql.Driver"}

# Чтение данных из PostgreSQL
df = spark.read.jdbc(url=pg_url, table="mock_data", properties=pg_properties)

# Проверка чтения данных
df.head(1)
```

Получаем первую строку:

```bash
[Row(id=1, customer_first_name='Barron', customer_last_name='Rawlyns', customer_age=61, customer_email='bmassingham0@army.mil', customer_country='China', customer_postal_code=None, customer_pet_type='cat', customer_pet_name='Priscella', customer_pet_breed='Labrador Retriever', seller_first_name='Bevan', seller_last_name='Massingham', seller_email='bmassingham0@answers.com', seller_country='Indonesia', seller_postal_code=None, product_name='Dog Food', product_category='Food', product_price=Decimal('77.97'), product_quantity=89, sale_date=datetime.date(2021, 5, 14), sale_customer_id=1, sale_seller_id=1, sale_product_id=1, sale_quantity=4, sale_total_price=Decimal('487.70'), store_name='Youopia', store_location='Suite 75', store_city='Xichehe', store_state=None, store_country='United States', store_phone='564-244-8660', store_email='bmassingham0@networkadvertising.org', pet_category='Cats', product_weight=Decimal('13.40'), product_color='Indigo', product_size='Medium', product_brand='Skajo', product_material='Steel', product_description='Aliquam quis turpis eget elit sodales scelerisque. Mauris sit amet eros. Suspendisse accumsan tortor quis turpis.\n\nSed ante. Vivamus tortor. Duis mattis egestas metus.', product_rating=Decimal('2.1'), product_reviews=97, product_release_date=datetime.date(2011, 10, 19), product_expiry_date=datetime.date(2028, 10, 21), supplier_name='Tagcat', supplier_contact='Bevan Massingham', supplier_email='bmassingham0@unblog.fr', supplier_phone='914-877-7062', supplier_address='Suite 25', supplier_city='Kletek', supplier_country='China')]
```

Строим модель снежинки:

```py
# ===================================================================
# 1. dim_date (surrogate key — date_id)
# ===================================================================
dim_date = df.select(col("sale_date").alias("full_date")) \
    .distinct() \
    .filter(col("full_date").isNotNull()) \
    .withColumn("date_id", row_number().over(Window.orderBy("full_date"))) \
    .withColumn("year", year("full_date")) \
    .withColumn("month", month("full_date")) \
    .withColumn("day", dayofmonth("full_date")) \
    .withColumn("quarter", quarter("full_date"))

dim_date.write.jdbc(url=pg_url, table="dim_date", mode="overwrite", properties=pg_properties)
# MORE
```

[Postgres.ipynb](./app/Postgres.ipynb)

Изображения полученных структур

![postgres](./images/postgres.png)

![postgres_struct](./images/postgres_struct.png)

Получившиеся колонки

```bash
Колонки fact_sales: ['sale_id', 'customer_id', 'pet_id', 'seller_id', 'product_id', 'store_id', 'supplier_id', 'date_id', 'sale_quantity', 'sale_total_price']
Колонки dim_product: ['product_id', 'name', 'category', 'price', 'weight', 'color', 'size', 'brand', 'material', 'description', 'rating', 'reviews', 'release_date', 'expiry_date']
Колонки dim_customer: ['customer_id', 'first_name', 'last_name', 'age', 'email', 'country', 'postal_code']
Колонки dim_store: ['store_name', 'store_location', 'store_city', 'store_state', 'store_country', 'store_phone', 'store_email', 'store_id']
Колонки dim_supplier: ['supplier_name', 'contact', 'supplier_email', 'supplier_phone', 'supplier_address', 'supplier_city', 'supplier_country', 'supplier_id']
Колонки dim_date: ['full_date', 'date_id', 'year', 'month', 'day', 'quarter']
```

Далее для всех других БД мы будем получать значения следующюю загрузку в качестве основы:

```python
# Загружаем все таблицы звезды
fact = spark.read.jdbc(url=pg_url, table="fact_sales", properties=pg_properties)
dim_product = spark.read.jdbc(url=pg_url, table="dim_product", properties=pg_properties)
dim_customer = spark.read.jdbc(url=pg_url, table="dim_customer", properties=pg_properties)
dim_store = spark.read.jdbc(url=pg_url, table="dim_store", properties=pg_properties)
dim_supplier = spark.read.jdbc(url=pg_url, table="dim_supplier", properties=pg_properties)
dim_date = spark.read.jdbc(url=pg_url, table="dim_date", properties=pg_properties)
dim_date.head(1)
```

### Формирование витрин в ClickHouse (обязательно)

Для ClickHouse таблицы создаются через HTTP API:

```python
import requests

def create_clickhouse_table(table_name, create_query):
    """Создание таблицы в ClickHouse через HTTP API"""
    try:
        url = "http://clickhouse:8123/"
        response = requests.post(url, data=create_query)
        if response.status_code == 200:
            print(f"✓ Таблица {table_name} создана")
            return True
        else:
            print(f"✗ Ошибка создания {table_name}: {response.text}")
            return False
    except Exception as e:
        print(f"✗ Ошибка при создании таблицы {table_name}: {e}")
        return False

# Создаем все таблицы
print("Создание таблиц в ClickHouse...")

# 1. Витрина продаж по продуктам
create_clickhouse_table("vitrina_product_sales", """
CREATE TABLE IF NOT EXISTS vitrina_product_sales (
    product_id UInt32,
    name String,
    category String,
    total_quantity UInt64,
    total_revenue Decimal(15,2),
    avg_rating Float32,
    review_count UInt32
) ENGINE = MergeTree()
ORDER BY (category, product_id)
""")
# MORE
```

```python
def write_to_clickhouse_existing(df, table_name):
    """Запись DataFrame в существующую таблицу ClickHouse"""
    try:
        df.write \
            .format("jdbc") \
            .option("url", ch_jdbc_url) \
            .option("dbtable", table_name) \
            .option("user", ch_properties["user"]) \
            .option("password", ch_properties["password"]) \
            .option("driver", ch_properties["driver"]) \
            .option("batchsize", 100000) \
            .mode("append") \
            .save()
        
        print(f"✓ Данные записаны в таблицу {table_name}")
        
    except Exception as e:
        print(f"✗ Ошибка при записи в таблицу {table_name}: {e}")

# ===============================
# 1. Витрина продаж по продуктам
# ===============================
print("Создание витрины продаж по продуктам...")
product_vitrina = fact.join(dim_product, fact.product_id == dim_product.product_id) \
    .groupBy(dim_product.product_id, dim_product.name, dim_product.category) \
    .agg(
        sum("sale_quantity").alias("total_quantity"),
        sum("sale_total_price").alias("total_revenue"),
        first("rating").alias("avg_rating"),
        first("reviews").alias("review_count")
    )

write_to_clickhouse_existing(product_vitrina, "vitrina_product_sales")

# Топ-10 самых продаваемых
top10_products = product_vitrina.orderBy(desc("total_quantity")).limit(10)
write_to_clickhouse_existing(top10_products, "top10_sold_products")

# Выручка по категориям
category_revenue = product_vitrina.groupBy("category") \
    .agg(sum("total_revenue").alias("category_revenue"))
write_to_clickhouse_existing(category_revenue, "category_revenue")
# MORE
```

Проверяем созданные таблицы и кол-во записей

```python
# Проверка данных
def check_table_count(table_name):
    """Проверка количества записей в таблице"""
    try:
        count_df = spark.read \
            .format("jdbc") \
            .option("url", ch_jdbc_url) \
            .option("dbtable", f"(SELECT count(*) as cnt FROM {table_name}) as t") \
            .option("user", ch_properties["user"]) \
            .option("password", ch_properties["password"]) \
            .option("driver", ch_properties["driver"]) \
            .load()
        count = count_df.first()["cnt"]
        print(f"✓ Таблица {table_name}: {count} записей")
        return count
    except Exception as e:
        print(f"✗ Ошибка при проверке таблицы {table_name}: {e}")
        return 0

print("\nПроверка загруженных данных:")
tables_to_check = [
    "vitrina_product_sales", "vitrina_customer_sales", "vitrina_time_sales",
    "vitrina_store_sales", "vitrina_supplier_sales", "vitrina_product_quality",
    "top10_sold_products", "top10_customers_by_spent", "top5_stores_by_revenue",
    "top5_suppliers_by_revenue", "product_quality_correlation"
]

for table in tables_to_check:
    check_table_count(table)
```

Получаем 

```bash
============================================================
ВСЕ ДАННЫЕ УСПЕШНО ЗАГРУЖЕНЫ В CLICKHOUSE!
============================================================

Проверка загруженных данных:
✓ Таблица vitrina_product_sales: 6210 записей
✓ Таблица vitrina_customer_sales: 10000 записей
✓ Таблица vitrina_product_quality: 2947 записей
✓ Таблица vitrina_time_sales: 12 записей
✓ Таблица top10_sold_products: 10 записей
✓ Таблица top10_customers_by_spent: 10 записей
✓ Таблица top5_stores_by_revenue: 5 записей
✓ Таблица top5_suppliers_by_revenue: 5 записей
✓ Таблица product_quality_correlation: 1 записей
...
```

**Результат загрузки:**

![clickhouse_struct](./imgs/clickhouse_struct.png)

![clickhouse_example](./imgs/clickhouse_example.png)

### Реализация витрин в MongoDB (бонус)

Функция для загрузки данных:

```python
def write_df_to_mongodb(df, collection_name, database_name="sales_dwh"):
    """Записывает DataFrame в MongoDB"""
    
    df.write \
        .format("mongo") \
        .mode("overwrite") \
        .option("uri", f"mongodb://root:password@mongo:27017/{database_name}.{collection_name}?authSource=admin") \
        .option("database", database_name) \
        .option("collection", collection_name) \
        .save()
    
    print(f"Данные успешно записаны в коллекцию {collection_name}")
```

Пример витрины

```python
# Витрина 1: Продажи по продуктам
product_sales_mart = fact.alias("f") \
    .join(dim_product.alias("p"), "product_id") \
    .groupBy("p.product_id", "p.name", "p.category") \
    .agg(
        sum("f.sale_quantity").alias("total_quantity_sold"),
        sum("f.sale_total_price").alias("total_revenue"),
        avg("p.rating").alias("average_rating"),
        sum("p.reviews").alias("total_reviews"),
        count("f.sale_id").alias("number_of_sales")
    ) \
```

После загрузки данных получаем

```bash
🚀 ЗАПУСК ПРОВЕРКИ MONGODB ЧЕРЕЗ SPARK
============================================================
🔍 Проверяем доступность коллекций:
✅ product_sales_mart: 6210 записей
✅ customer_sales_mart: 10000 записей
✅ time_sales_mart: 12 записей
✅ store_sales_mart: 1611 записей
✅ supplier_sales_mart: 10000 записей
✅ product_quality_mart: 9982 записей

📊 Витрина продаж по продуктам (product_sales_mart):
Схема данных:
root
 |-- _id: struct (nullable = true)
 |    |-- oid: string (nullable = true)
 |-- average_rating: decimal(6,5) (nullable = true)
 |-- category: string (nullable = true)
 |-- mart_type: string (nullable = true)
 |-- name: string (nullable = true)
 |-- number_of_sales: long (nullable = true)
 |-- product_id: integer (nullable = true)
 |-- total_quantity_sold: long (nullable = true)
 |-- total_revenue: decimal(7,2) (nullable = true)
 |-- total_reviews: long (nullable = true)

Первые 10 записей:
+--------------------------+--------------+--------+-------------+---------+---------------+----------+-------------------+-------------+-------------+
|_id                       |average_rating|category|mart_type    |name     |number_of_sales|product_id|total_quantity_sold|total_revenue|total_reviews|
+--------------------------+--------------+--------+-------------+---------+---------------+----------+-------------------+-------------+-------------+
|{691cb7db428c6c622582717e}|3.06667       |Toy     |product_sales|Bird Cage|30             |471       |168                |7614.12      |4930         |
|{691cb7db428c6c622582717f}|2.05000       |Cage    |product_sales|Cat Toy  |20             |471       |112                |5076.08      |4350         |
|{691cb7db428c6c6225827180}|2.20000       |Food    |product_sales|Bird Cage|10             |471       |56                 |2538.04      |1660         |
|{691cb7db428c6c6225827181}|3.46667       |Cage    |product_sales|Bird Cage|30             |471       |168                |7614.12      |9460         |
|{691cb7db428c6c6225827182}|1.70000       |Toy     |product_sales|Dog Food |10             |471       |56                 |2538.04      |4890         |
|{691cb7db428c6c6225827183}|4.10000       |Food    |product_sales|Cat Toy  |30             |148       |162                |9441.84      |8300         |
|{691cb7db428c6c6225827184}|3.15000       |Food    |product_sales|Bird Cage|20             |148       |108                |6294.56      |6900         |
|{691cb7db428c6c6225827185}|2.30000       |Cage    |product_sales|Cat Toy  |20             |148       |108                |6294.56      |15260        |
|{691cb7db428c6c6225827186}|4.00000       |Food    |product_sales|Dog Food |10             |148       |54                 |3147.28      |8080         |
|{691cb7db428c6c6225827187}|1.00000       |Toy     |product_sales|Cat Toy  |10             |148       |54                 |3147.28      |8540         |
+--------------------------+--------------+--------+-------------+---------+---------------+----------+-------------------+-------------+-------------+
only showing top 10 rows

Количество записей: 6210
Доступные колонки: ['_id', 'average_rating', 'category', 'mart_type', 'name']

📊 Витрина продаж по клиентам (customer_sales_mart):
...
```

### Neo4j

Создание таблиц в `Neo4j` ghbvth

```python
# 1. Витрина продаж по продуктам
def create_product_sales_mart():
    product_sales = fact \
        .join(dim_product, "product_id") \
        .groupBy("product_id", "name", "category") \
        .agg(
            sum("sale_quantity").alias("total_quantity"),
            sum("sale_total_price").alias("total_revenue"),
            avg("rating").alias("avg_rating"),
            sum("reviews").alias("total_reviews")
        ) \
        .orderBy(desc("total_quantity")) \
        .limit(10)
    
    return convert_numeric_types(product_sales)
```

Посмотрим пример запроса в `Neo4j` для того, чтобы понять, что данные корректно загрузились:

![neo4j.png](./imgs/neo4j.png)

### ValkРеализация витрин в Valkey (бонус)ey

Valkey используется для хранения агрегированных показателей в формате ключ-значение.

```python
# Конфигурация Valkey
valkey_config = {
    "host": "valkey",
    "port": 6379,
    "db": 0,
    "password": "bigdata2024",  # пароль из docker-compose
    "decode_responses": True
}

spark = SparkSession.builder \
    .appName("ValkeyETL") \
    .getOrCreate()
```

После установления подключения и создания витрин, проверяем данные:

```bash
✓ Valkey подключение успешно
🚀 Начало ETL процесса в Valkey...
📥 Загрузка данных из PostgreSQL...
✅ Данные успешно загружены из PostgreSQL
Схема fact_sales:
root
 |-- sale_id: integer (nullable = true)
 |-- customer_id: integer (nullable = true)
 |-- pet_id: integer (nullable = true)
 |-- seller_id: integer (nullable = true)
 |-- product_id: integer (nullable = true)
 |-- store_id: integer (nullable = true)
 |-- supplier_id: integer (nullable = true)
 |-- date_id: integer (nullable = true)
 |-- sale_quantity: integer (nullable = true)
 |-- sale_total_price: decimal(12,2) (nullable = true)

Схема dim_product:
root
 |-- product_id: integer (nullable = true)
 |-- name: string (nullable = true)
 |-- category: string (nullable = true)
 |-- price: decimal(10,2) (nullable = true)
 |-- weight: decimal(8,2) (nullable = true)
 |-- color: string (nullable = true)
 |-- size: string (nullable = true)
 |-- brand: string (nullable = true)
 |-- material: string (nullable = true)
 |-- description: string (nullable = true)
 |-- rating: decimal(3,1) (nullable = true)
 |-- reviews: integer (nullable = true)
 |-- release_date: date (nullable = true)
 |-- expiry_date: date (nullable = true)

=== Создание витрины продаж по продуктам ===
Топ-10 продуктов:
+----------+---------+--------+--------------+-------------+----------+-------------+
|product_id|     name|category|total_quantity|total_revenue|avg_rating|total_reviews|
+----------+---------+--------+--------------+-------------+----------+-------------+
|       380|  Cat Toy|    Food|           408|     12538.44|   2.76667|        34470|
|        46| Dog Food|     Toy|           366|     15406.26|   2.98333|        22460|
|       995| Dog Food|    Cage|           348|     14523.84|   3.68333|        33010|
|       187|  Cat Toy|    Cage|           345|     11105.05|   2.28000|        28460|
|       673|Bird Cage|    Food|           320|      8453.16|   2.70000|        17940|
|       692|  Cat Toy|    Food|           320|     11856.56|   2.37500|        24670|
|       235|Bird Cage|    Food|           315|     12946.25|   3.32000|        26470|
|       699|Bird Cage|     Toy|           308|     10764.52|   2.62500|        20430|
|       387| Dog Food|    Food|           295|     13187.85|   2.94000|        35210|
|       621|  Cat Toy|    Cage|           295|     10663.55|   4.00000|        39060|
+----------+---------+--------+--------------+-------------+----------+-------------+
...
```

В ходе лабораторной работы был реализован полный ETL-пайплайн на Apache Spark, начиная от загрузки CSV-данных и заканчивая формированием аналитических витрин в нескольких NoSQL-базах данных. Работа позволила закрепить навыки проектирования хранилищ данных и интеграции Spark с различными СУБД.
