import pendulum

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.docker.operators.docker import Mount
from airflow.providers.docker.operators.docker import DockerOperator
from datetime import timedelta

from functions import (
    load_data_to_clickhouse,
    unzip_and_add_metadata,
    generate_file_urls,
    download_files
)
from config import (
    CLICKHOUSE_USER,
    CLICKHOUSE_PASSWORD,
    CLICKHOUSE_DATABASE
)

with DAG(
    dag_id='lab08',
    default_args={
        'owner': 'airflow',
        'depends_on_past': False,
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 1,
        'retry_delay': timedelta(minutes=1)
    },
    description='Пайплайн загрузки и обработки данных из S3',
    schedule_interval='@hourly',
    start_date=pendulum.datetime(2024, 12, 1, 0, 0),
    catchup=True,
    max_active_runs=1
) as dag:

    generate_file_urls = PythonOperator(
        task_id='generate_file_urls',
        python_callable=generate_file_urls,
        provide_context=True
    )

    download_files = PythonOperator(
        task_id='download_files',
        python_callable=download_files,
        provide_context=True
    )

    unzip_files = PythonOperator(
        task_id='unzip_and_add_metadata',
        python_callable=unzip_and_add_metadata,
        provide_context=True
    )

    load_data_to_clickhouse = PythonOperator(
        task_id='load_data_to_clickhouse',
        python_callable=load_data_to_clickhouse,
        provide_context=True
    )

    dbt_run = DockerOperator(
        task_id='dbt_run',
        image='andart000/de15lab06:latest',
        command='dbt run',
        docker_url='unix://var/run/docker.sock',
        network_mode="lab08_lab08_network",
        auto_remove=True,
        environment={
            'CLICKHOUSE_USER': CLICKHOUSE_USER,
            'CLICKHOUSE_PASSWORD': CLICKHOUSE_PASSWORD,
            'CLICKHOUSE_DATABASE': CLICKHOUSE_DATABASE,
            'DBT_PROFILES_DIR': '/root/.dbt'
        },
        mounts=[
            Mount(source='/home/ubuntu/labs/lab08/dbt_lab08', target='/dbt_lab08', type='bind'),
            Mount(source='/home/ubuntu/.dbt', target='/root/.dbt', type='bind')
        ],
        working_dir='/dbt_lab08'
    )
    
    
    generate_file_urls >> download_files >> unzip_files >> load_data_to_clickhouse >> dbt_run

