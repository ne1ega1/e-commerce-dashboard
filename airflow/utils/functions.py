"""Функциональный модуль"""

import json
import zipfile
import logging
import requests

from time import sleep
from datetime import datetime
from clickhouse_driver import Client

from config import (
    BUCKET_URL,
    COUNT_QUERY,
    TABLE_MAPPING,
    DATE_FILE_PATTERN,
    LOCAL_STORAGE_PATH,
    UNZIP_FILES_PATH,
    CLICKHOUSE_HOST,
    CLICKHOUSE_PORT,
    CLICKHOUSE_USER,
    CLICKHOUSE_PASSWORD,
    CLICKHOUSE_DATABASE
)


def generate_file_urls(execution_date, **kwargs):
    """Генерация списка URL для загрузки файлов на основе даты запуска DAG"""

    year = execution_date.strftime('%Y')
    month = execution_date.strftime('%m')
    day = execution_date.strftime('%d')
    hour = execution_date.strftime('%H')
    
    base_path = f'year={year}/month={month}/day={day}/hour={hour}'

    files = [
        f'{BUCKET_URL}/{base_path}/browser_events.jsonl.zip',
        f'{BUCKET_URL}/{base_path}/device_events.jsonl.zip',
        f'{BUCKET_URL}/{base_path}/geo_events.jsonl.zip',
        f'{BUCKET_URL}/{base_path}/location_events.jsonl.zip'
    ]
    
    kwargs['ti'].xcom_push(
        key='file_urls',
        value=files
    )

    logging.info(f'Generated file URLs: {files}')


def download_files(**kwargs):
    """Загрузка файлов по сгенерированным URL"""

    file_urls = kwargs['ti'].xcom_pull(
        key='file_urls',
        task_ids='generate_file_urls'
    )
    
    if not file_urls:
        raise ValueError('No file URLs to download')

    if not LOCAL_STORAGE_PATH.exists():
        LOCAL_STORAGE_PATH.mkdir(
            parents=True,
            exist_ok=True
        )
    
    for url in file_urls:
        date_match = DATE_FILE_PATTERN.match(url)

        if not date_match:
            raise ValueError(f'Invalid format of file URL: {url}')

        file_name_year = date_match.group('year')
        file_name_month = date_match.group('month')
        file_name_day = date_match.group('day')
        file_name_hour = date_match.group('hour')
        file_name = date_match.group('filename')
        
        output_file_name = f'{file_name_year}-{file_name_month}-{file_name_day}-{file_name_hour}_{file_name}'
        local_file_path = LOCAL_STORAGE_PATH / output_file_name

        logging.info(f'Downloading {url} to {str(local_file_path)}')
        
        response = requests.get(url, stream=True)

        if response.status_code == 200:
            with open(local_file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)

            logging.info(f'Downloaded {str(local_file_path)}')

        else:
            raise Exception(f'Failed to download {url}. HTTP Status: {response.status_code}')


def unzip_and_add_metadata(**kwargs):
    """Разархивирование файлов и добавление метаданных"""

    unzip_files = []
    
    if not UNZIP_FILES_PATH.exists():
        UNZIP_FILES_PATH.mkdir(
            parents=True,
            exist_ok=True
        )
    
    for file_name in LOCAL_STORAGE_PATH.glob('*.zip'):
        local_file_path = LOCAL_STORAGE_PATH / file_name

        logging.info(f'Unzipping {str(local_file_path)} to {UNZIP_FILES_PATH}')

        file_key_date = file_name.stem.split('_')[0]
        file_date = datetime.strptime(file_key_date, '%Y-%m-%d-%H').strftime('%Y-%m-%d %H:%M:%S')
        
        with zipfile.ZipFile(local_file_path, 'r') as zip_ref:
            for zip_file_name in zip_ref.namelist():
                extracted_file_path = UNZIP_FILES_PATH / f"{file_key_date}_{zip_file_name}"
                string_count = 0

                with zip_ref.open(zip_file_name) as extracted_file:
                    with open(extracted_file_path, 'w', encoding='utf-8') as output_file:
                        for line in extracted_file:
                            data = json.loads(line)
                            data['file_key_date'] = file_date
                            output_file.write(json.dumps(data) + '\n')
                            string_count += 1

                    unzip_files.append(
                        dict(
                            file_path=str(extracted_file_path),
                            file_str_count=string_count,
                            file_date=file_date
                        )
                    )

        local_file_path.unlink()
        logging.info(f'Processed and removed {local_file_path}')

    kwargs['ti'].xcom_push(
        key='unzip_files',
        value=unzip_files
    )


def load_data_to_clickhouse(**kwargs):
    """Загрузка распакованных файлов в таблицы ClickHouse"""

    unzip_files = kwargs['ti'].xcom_pull(
        key='unzip_files',
        task_ids='unzip_and_add_metadata'
    )

    if not unzip_files:
        raise ValueError('No unzip files to load')

    client = Client(
        host=CLICKHOUSE_HOST,
        port=CLICKHOUSE_PORT,
        user=CLICKHOUSE_USER,
        password=CLICKHOUSE_PASSWORD,
        database=CLICKHOUSE_DATABASE
    )

    for file_info in sorted(unzip_files, key=lambda x: x['file_path'], reverse=True):
        table_name = ''
        logging.info(f'Loading {file_info["file_path"]} to ClickHouse base {CLICKHOUSE_DATABASE}')

        file_path = file_info['file_path']
        # file_key_date = file_info['file_date']

        for events, table in TABLE_MAPPING.items():
            if events in file_path:
                table_name = table
                break

        if not table_name:
            raise ValueError(f'Unknown table name for {file_path}')

      # Задел на пересчет данных, пока не реализовано
      # client.execute(
      #     f"ALTER TABLE {CLICKHOUSE_DATABASE}.{table_name} DELETE WHERE file_key_date = toDateTime('{file_key_date}');"
      # )
      # sleep(5)

        with open(file_path, 'r', encoding='utf-8') as f:
           data = f.read()

        current_count = int(
            client.execute(
                COUNT_QUERY.format(
                    database=CLICKHOUSE_DATABASE,
                    table=table_name
                )
            )[0][0]
        )

        count_table = file_info['file_str_count']
        target_count = current_count + count_table
        
        client.execute(
           f'INSERT INTO {CLICKHOUSE_DATABASE}.{table_name} FORMAT JSONEachRow {data}'
        )

        while current_count < target_count:
            logging.info(f'Waiting to load {file_path} in {table_name} 5 seconds')
            sleep(5)
            current_count = int(
                client.execute(
                    COUNT_QUERY.format(
                        database=CLICKHOUSE_DATABASE,
                        table=table_name
                    )
                )[0][0]
            )
    
