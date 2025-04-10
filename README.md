# de-zoomcamp-proj-sf-business
This is the final project repo of the DE zoomcamp 2025 cohort

## Problem statement and results
In this project, we utlized the data of registered business in San Francisco from https://data.sfgov.org/Economy-and-Community/Registered-Business-Locations-San-Francisco/g8m3-pdis/about_data, and tries to answer the following questions:
1. How long do companies stay in business in SF?
2. What are the most poplular business areas in SF?
3. How many restaurants opens or closes in the past 10 years?

The results are shown in the following dashboard: 

<img width="808" alt="Screenshot 2025-04-10 at 10 23 15 PM" src="https://github.com/user-attachments/assets/f9a614c9-1720-45de-9549-75e0fa8e6f8d" />

## Steps
In this section, we give a step-by-step walkthrough of the project. This will include platform setup with terraform, data ingestion and pre-process with Kestra, detailed data process with dbt, and final dashboard setup with Looker studio.

See the flowchart attached:

<img width="888" alt="Screenshot 2025-04-10 at 9 59 15 PM" src="https://github.com/user-attachments/assets/8b5c27b0-d934-4a07-a112-5925f5d5ef21" />

### Setup Google Cloud Platform and other infrastructures
In this project, we are using the Google Cloud Platform (GCP). We setup the following:
1. Create a service account with BigQuery Admin, Storage Admin, and Compute Admin.
2. Store the credential file (.json) in ./key folder.
3. Run the main.tf file to establish Data Storage Bitbucket and Bigquery dataset.

(Step 1-3 can be done following the instructions from: https://www.youtube.com/watch?v=Y2ux7gq3Z0o&list=PL3MmuxUbc_hJed7dXYoJw8DoCuVHhGEQb&index=12)

4. Create a virtual machine (VM).
5. Install docker, docker compose, and Python in the VM.
6. Setup config file in ~/.ssh folder. The file is not shown here as it's rather straightforward and the IP address will vary)
7. Use VSCode to connect to VM

(Step 4-7 can be done following the instructions from: https://www.youtube.com/watch?v=ae-CV2KfoN0&list=PL3MmuxUbc_hJed7dXYoJw8DoCuVHhGEQb&index=14)
### Data ingestion with Kestra
After setting up the VM as well as docker compose, you can copy the docker-compose.yml in the repo, and launch Kestra with
```bash
docker-compose up -d
```
To interact with Kestra from browser, you should also forward port 8080 from the VM to your localhost. (See 32:45 of https://www.youtube.com/watch?v=ae-CV2KfoN0&list=PL3MmuxUbc_hJed7dXYoJw8DoCuVHhGEQb&index=14)

Create the key-value pairs to connect to you Cloud Storage and BigQuery. Especially, remember the `GCP-CREDS` that contains the credential information. 

Create a flow in Kestra, and copy the content in kestra_data_ingestion_flow.yml into the flow. We hereby explain a couple of key parts in the flow:
```yml
inputs:
  - id: total_rows
    type: INT
    defaults: 340000
  - id: row_limit
    type: INT
    defaults: 50000
```
The input of the flow include the total rows of the data (`total_rows`), and how many rows you want to include in a standalone file (`row_limit`), as transferring too much data once may introduce some stability issue. 

The number total_rows should be a number roughly larger than the actual number of rows. For example, at the moment of drafting this document, the dataset has 339,663 rows, so we set the number here as 340,000.

The `row_limit` is the number of rows that will be contained in a standalone file. The all 339,663 rows of data mentioned before will be separated into a couple of files. For example, when `row_limit=50000`, the first file will contain row 1 to row 50,000, and the second file will contain row 50,001 to row 100,000 etc. The number should not be too large, for not saving and transferring too large a file. The number also should not be too small, as each standalone file will go through all the processes, and the overhead for processing the files can add up.

```yml
  - id: generate_offsets
    type: io.kestra.plugin.scripts.python.Script
    script: |
      from kestra import Kestra
      offset_list = [str(i) for i in range(0,{{inputs.total_rows}},{{inputs.row_limit}})]
      Kestra.outputs({'results':offset_list})
```
This task uses Python script in Kestra to generate a list of offset values into a value called `offset_list`. The offset value will be then added to the url when downloading file. The downloaded file will start with row offset+1. For example, if you run 
```bash
wget https://data.sfgov.org/resource/g8m3-pdis.csv?\$limit=1000\&\$offset=500
```
Row 501 to row 1500 will be downloaded. The value following `offset=` is the offset value we talk about here, and the value following `limit=` is already setup in the `row_limit` in `inputs`.

```yml
  - id: process_by_page
    type: io.kestra.plugin.core.flow.ForEach
    values: "{{ outputs.generate_offsets.vars.results}}"
    concurrencyLimit: 1
    tasks:
```
This task type `ForEach` will run for each value in the input list, which is the `offset_list` we mentioned in the previou task (`generate_offsets`). Note the list is not passed by the list name, but by the variable name `{{ outputs.generate_offsets.vars.results}}`.

For each offset value, a series of tasks will be run. We briefly describe each task here:
1. `extract`: download the data and write it as a .csv file.
2. `upload_to_gcs`: upload the downloaded file to Cloud Storage. Files with identical names will be overwritten.
3. `bq_sf_business_data`: create the overall table `sf_business_data` if the table does not exist.
4. `bq_sf_business_data_ext`: create external table from .csv file uploaded to Cloud Storage. Some dummy columns are added to make sure row number in external table and in .csv file are identical.
5. `bq_sf_business_table_tmp`: copy the external table to a table in BigQuery. A column `unique_row_id` is added as the identifier of each row.
6. `bq_sf_business_merge`: merge the table containing data from only 1 file to the overall table `sf_business_data`. A row will only be added if the value of `unique_row_id` does not exist in the overall table.

After the aforementioend steps are done for each file, we delete all the temporary files with task `purge_files`. Up till now, all the data should already be stored in Cloud Storage, and the data needed should all be in the table `sf_business_data`. We are now ready to futher process it with dbt and generate the data needed for the dashboard. 

One more thing before we leave the Kestra section: when a task is run more than once, merely task_id is insufficient for finding a specific task run. For example, the `extract` task here is run once for each offset value. To obtain the downloaded file for a task run, the `vars.data` is constructed as following:
```yml
  data: "{{outputs.extract[taskrun.value].outputFiles['g8m3-pdis-offset-' ~ taskrun.value ~ '.csv']}}"
```
Note the `[taskrun.value]` after the `extract`. The `taskrun.value` is the current value in the `ForEach` task. This will guide Kestra to find the `extract` task run for that offset value, and thus the downloaded file.

### Data transformation with dbt
In this section, 4 fact tables and 3 dimension tables were generated and sent to BigQuery. The 4 fact tables include (1) the master fact table of all registered business records in SF; (2) the aggregated monthly business activities by business location start date; (3) all registered business records in SF for inactive business locations; (4) all registered business records in SF for businesses with at least one active location. the 4 fact tables should be able to meet the daily analytics needs with different areas of focus and granularities.

The dbt lineage chart is as below:

<img width="907" alt="Screenshot 2025-04-10 at 8 45 49 PM" src="https://github.com/user-attachments/assets/7ab0a4be-caf2-4b44-946d-6e1689131b32" />


Two tests were run during the staging table build, the purpose of which is to ensure that all LIC and NAIC codes appear in LIC and NAIC lookup tables, so that we know no wrong codes were used in the fact table.

The model shcema yml file contains descriptions of the final fact table and the columns in it. Dbt auto-generate documentations based on that.

Finally, submit a dbt deploy job and trigger it. The transformed data are now sent back to the data warehouse(BigQuery).

(Please find detailed dbt models and files under the 'dbt' folder.)
