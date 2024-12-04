"""Конфигурационные параметры"""

import re

from pathlib import Path
from airflow.models import Variable


CLICKHOUSE_HOST=Variable.get("clickhouse_host")

CLICKHOUSE_PORT=Variable.get("clickhouse_port")

CLICKHOUSE_USER=Variable.get("clickhouse_user")

CLICKHOUSE_PASSWORD=Variable.get("clickhouse_password")

CLICKHOUSE_DATABASE=Variable.get("clickhouse_database")

BUCKET_URL = Variable.get("bucket_url")

LOCAL_STORAGE_PATH = Path(Variable.get("local_storage_path"))

UNZIP_FILES_PATH = Path(Variable.get("unzip_files_path"))

DATE_FILE_PATTERN = re.compile(
    r'.*year=(?P<year>\d{4})\/month=(?P<month>\d{2})\/day=(?P<day>\d{2})\/hour=(?P<hour>\d{2})\/(?P<filename>[\w\._]+)'
)

COUNT_QUERY = 'SELECT COUNT(1) FROM {database}.{table}'

TABLE_MAPPING = dict(
    browser_events='raw_browser_events',
    device_events='raw_device_events',
    geo_events='raw_geo_events',
    location_events='raw_location_events'
)
