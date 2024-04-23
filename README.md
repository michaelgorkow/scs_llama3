# META's Llama 3 in Snowpark Container Services
This repository explains how to run META's [Llama 3](https://llama.meta.com/llama3/) in Snowpark Container Services.  
You can access the related blog article here:  
[Llama 3 in Snowflake](https://medium.com/@michaelgorkow/496863631700?source=friends_link&sk=c912452d8427d999f800777cc01f6d88)

## Requirements
* Snowflake Account with Snowpark Container Services
* Docker installed

## Setup Instructions
### 1. Setup the Snowflake environment
```sql
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS LLAMA3;
-- Stage where we'll store service specifications
CREATE STAGE IF NOT EXISTS LLAMA3.PUBLIC.CONTAINER_FILES
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE') 
    DIRECTORY = (ENABLE = TRUE);
-- Stage where we'll store Llama 3 model files
CREATE STAGE IF NOT EXISTS LLAMA3.PUBLIC.LLAMA3_MODELS 
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE') 
    DIRECTORY = (ENABLE = TRUE);

-- Create Compute Pool in which Llama 3 service will be executed
CREATE COMPUTE POOL LLAMA3_GPU_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = GPU_NV_S;

-- Create Image Repository
CREATE IMAGE REPOSITORY LLAMA3.PUBLIC.IMAGE_REPOSITORY;

-- Create External Access Integration (to download LLama 3 models)
CREATE OR REPLACE NETWORK RULE LLAMA3.PUBLIC.LLAMA3_NETWORK_RULE
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('0.0.0.0:443','0.0.0.0:80');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION LLAMA3_ACCESS_INTEGRATION
    ALLOWED_NETWORK_RULES = (LLAMA3.PUBLIC.LLAMA3_NETWORK_RULE)
    ENABLED = true;

-- Create a secret for downloading Hugging Face Models
CREATE SECRET LLAMA3.PUBLIC.HUGGINGFACE_TOKEN
    TYPE = GENERIC_STRING
    SECRET_STRING = 'hf_<your-token>'
    COMMENT = 'Hugging Face User Access Token';

-- Create a custom role for Llama 3 services
-- Grants for custom role to create and run Llama3 service
CREATE OR REPLACE ROLE LLAMA3_ROLE;
GRANT USAGE ON DATABASE LLAMA3 TO ROLE LLAMA3_ROLE;
GRANT USAGE ON SCHEMA LLAMA3.PUBLIC TO ROLE LLAMA3_ROLE;
GRANT READ ON IMAGE REPOSITORY LLAMA3.PUBLIC.IMAGE_REPOSITORY TO ROLE LLAMA3_ROLE;
GRANT CREATE FUNCTION ON SCHEMA LLAMA3.PUBLIC TO ROLE LLAMA3_ROLE;
GRANT CREATE SERVICE ON SCHEMA LLAMA3.PUBLIC TO ROLE LLAMA3_ROLE;
GRANT READ ON STAGE LLAMA3.PUBLIC.CONTAINER_FILES TO ROLE LLAMA3_ROLE;
GRANT READ, WRITE ON STAGE LLAMA3.PUBLIC.LLAMA3_MODELS TO ROLE LLAMA3_ROLE;
GRANT USAGE, OPERATE, MONITOR ON COMPUTE POOL LLAMA3_GPU_POOL TO ROLE LLAMA3_ROLE;
GRANT USAGE ON NETWORK RULE LLAMA3.PUBLIC.LLAMA3_NETWORK_RULE TO ROLE LLAMA3_ROLE;
GRANT USAGE ON INTEGRATION LLAMA3_ACCESS_INTEGRATION TO ROLE LLAMA3_ROLE;
GRANT USAGE ON SECRET LLAMA3.PUBLIC.HUGGINGFACE_TOKEN TO ROLE LLAMA3_ROLE;
GRANT READ ON SECRET LLAMA3.PUBLIC.HUGGINGFACE_TOKEN TO ROLE LLAMA3_ROLE;
GRANT ROLE LLAMA3_ROLE TO USER ADMIN; --add your username here
```

### 2. Clone this repository
```bash
git clone https://github.com/michaelgorkow/scs_llama3.git
```

### 3. Build & Upload the container
```cmd
cd scs_llama3
docker build -t <ORGNAME>-<ACCTNAME>.registry.snowflakecomputing.com/LLAMA3/PUBLIC/IMAGE_REPOSITORY/llama3_service:latest .
docker push <ORGNAME>-<ACCTNAME>.registry.snowflakecomputing.com/LLAMA3/PUBLIC/IMAGE_REPOSITORY/llama3_service:latest
```

### 4. Upload the Service Specification
You can use Snowflake's UI to upload the llama3_8b_spec.yml to @LLAMA3.PUBLIC.CONTAINER_FILES.  
<img src="assets/file_upload.png" width="70%" height="70%">

### 5. Create the Llama 3 Service
```sql
-- Create Llama 3 service
CREATE SERVICE LLAMA3.PUBLIC.LLAMA3_8B_SERVICE
  IN COMPUTE POOL LLAMA3_GPU_POOL
  FROM @LLAMA3.PUBLIC.CONTAINER_FILES
  SPEC='llama3_8b_spec.yml'
  MIN_INSTANCES=1
  MAX_INSTANCES=1
  EXTERNAL_ACCESS_INTEGRATIONS = (LLAMA3_ACCESS_INTEGRATION);

-- Verify Service is running
SELECT SYSTEM$GET_SERVICE_STATUS('LLAMA3_8B_SERVICE');
-- View Service Logs
SELECT SYSTEM$GET_SERVICE_LOGS('LLAMA3_8B_SERVICE',0,'llama3-8b-service-container');
```

### 6. Create the service functions
```sql
-- Create service function for simple function
CREATE OR REPLACE FUNCTION LLAMA3.PUBLIC.LLAMA3_8B_COMPLETE(INPUT_PROMPT TEXT)
RETURNS TEXT
SERVICE=LLAMA3.PUBLIC.LLAMA3_8B_SERVICE
ENDPOINT=API
AS '/complete';

-- Create service function for custom function
CREATE OR REPLACE FUNCTION LLAMA3.PUBLIC.LLAMA3_8B_COMPLETE_CUSTOM(SYSTEM_PROMPT TEXT, INPUT_PROMPT TEXT, MAX_NEW_TOKENS INT, TEMPERATURE FLOAT, TOP_P FLOAT)
RETURNS TEXT
SERVICE=LLAMA3.PUBLIC.LLAMA3_8B_SERVICE
ENDPOINT=API
AS '/complete_custom';
```

### 7. Call the service functions
```sql
-- Chat with Llama 3 with default settings:
SELECT LLAMA3.PUBLIC.LLAMA3_8B_COMPLETE('Generate the next 3 numbers for this Fibonacci sequence: 0, 1, 1, 2') AS RESPONSE;

-- Define system_prompt, max_token, temperature and top_p yourself:
SELECT LLAMA3.PUBLIC.LLAMA3_8B_COMPLETE_CUSTOM(
    'You are a coding assistant for Python. Only return Python code.', 
    'Write Python code to generate the fibonacci sequence.', 
    1024, 
    0.6, 
    0.9) AS RESONSE;
```

## Demo Video