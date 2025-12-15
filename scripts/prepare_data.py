import os
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).parent.parent.resolve()
DATA_DIR = ROOT / "data"
OUTPUT_FILE = DATA_DIR / "merged.csv"

# Находим все CSV-файлы в директории
files = [
    os.path.join(DATA_DIR, f)
    for f in os.listdir(DATA_DIR)
    if f.endswith(".csv")
]

print(f"Найдено файлов: {len(files)}")
for f in files:
    print(" -", f)

# Читаем и объединяем
df_list = []
for file in files:
    try:
        df = pd.read_csv(file)
        # Убираем старый столбец 'id'
        if 'id' in df.columns:
            df = df.drop(columns=['id'])
        df_list.append(df)
    except Exception as e:
        print(f"Ошибка при чтении {file}: {e}")

# Соединяем в один DataFrame
merged = pd.concat(df_list, ignore_index=True)

# Создаём новый уникальный id
merged.insert(0, 'id', range(1, len(merged) + 1))

# Сохраняем в CSV
merged.to_csv(OUTPUT_FILE, index=False)

print(f"\nГотово! Сохранено в: {OUTPUT_FILE}")
print(f"Общее число записей: {len(merged)}")
