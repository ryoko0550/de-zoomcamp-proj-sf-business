# de-zoomcamp-proj-sf-business
This is the final project repo of the DE zoomcamp 2025 cohort

## Problem statement and results
In this project, we utlized the data of registered business in San Francisco from https://data.sfgov.org/Economy-and-Community/Registered-Business-Locations-San-Francisco/g8m3-pdis/about_data, and tries to answer the following questions:
1. How long do companies stay in business in SF?
2. What are the most poplular business areas in SF?
3. How many restaurants opens or closes in the past 10 years?

The results are shown in the following dashboard: 
<img width="1130" alt="Screenshot 2025-04-09 at 8 48 42 PM" src="https://github.com/user-attachments/assets/7b46f058-a182-406b-98ac-911042f0f635" />

## Steps
In this section, we give a step-by-step walkthrough of the project. This will include platform setup with terraform, data ingestion and pre-process with Kestra, detailed data process with dbt, and final dashboard setup with Looker studio.
### Setup Google Cloud Platform and other infrastructures
In this project, we are using the Google Cloud Platform (GCP). We setup the following:
1. Create a service account with BigQuery Admin, Storage Admin, and Compute Admin.
2. Store the credential file (.json) in ./key folder.
3. Run the main.tf file to establish Data Storage Bitbucket and Bigquery dataset.

(Step 1-3 can be done following the instructions from: https://www.youtube.com/watch?v=Y2ux7gq3Z0o&list=PL3MmuxUbc_hJed7dXYoJw8DoCuVHhGEQb&index=12)
5. Create a virtual machine (VM).
6. Install docker, docker compose, and Python in the VM.
7. Setup config file in ~/.ssh folder. The file is not shown here as it's rather straightforward and the IP address will vary)
8. Use VSCode to connect to VM

(Step 4-7 can be done following the instructions from: https://www.youtube.com/watch?v=ae-CV2KfoN0&list=PL3MmuxUbc_hJed7dXYoJw8DoCuVHhGEQb&index=14)
### Data ingestion with Kestra
After setting up the VM as well as docker compose, you can copy the docker-compose.yml in the repo, and launch Kestra with
```bash
docker-compose up -d
```
To interact with Kestra from browser, you should also forward port 8080 from the VM to your localhost. (See 32:45 of https://www.youtube.com/watch?v=ae-CV2KfoN0&list=PL3MmuxUbc_hJed7dXYoJw8DoCuVHhGEQb&index=14)

Create a flow in Kestra, and copy the content in kestra_data_ingestion_flow.yml into the flow. We hereby explain a couple of key tasks in the flow:
```yml
inputs:
  - id: total_rows
    type: INT
    defaults: 340000
  - id: row_limit
    type: INT
    defaults: 50000
```
The input of the flow include the total rows of the data (total_rows), and how many rows you want to include in a standalone file (row_limit), as transferring too much data once may introduce some stability issue. 

The number total_rows should be a number roughly larger than the actual number of rows. For example, at the moment of drafting this document, the dataset has 339,663 rows, so we set the number here as 340,000.

The row_limit is the number of rows that will be contained in a standalone file. The all 339,663 rows of data mentioned before will be separated into a couple of files. For example, when row_limit=500, the first file will contain row 1 to row 50,000, and the second file will contain row 50,001 to row 100,000 etc. The number should not be too large, for not saving and transferring too large a file. The number also should not be too small, as each standalone file will go through all the processes, and the overhead for processing the files can add up.


