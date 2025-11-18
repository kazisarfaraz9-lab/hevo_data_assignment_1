# Assignment 1 – Step-by-Step Reproduction Guide

This document explains how to recreate the entire Assignment-1 workflow:

- Setting up PostgreSQL locally using Docker
- Creating and loading sample data
- Exposing PostgreSQL for remote connectivity
- Connecting PostgreSQL → Hevo
- Setting up Snowflake as destination via Partner Connect
- Running logical replication
- Applying required Hevo transformations
- Validating data in Snowflake
- Preparing deliverables

## 1. Install Prerequisites

You need the following installed:

- Docker Desktop
Download from: https://www.docker.com/products/docker-desktop/

- Snowflake Free Trial
Sign up at: https://signup.snowflake.com/

- Hevo via Snowflake Partner Connect
Activated later during the setup.

- ngrok / Cloudflare Tunnel


## 2. Set Up PostgreSQL in Docker

Run PostgreSQL 14 container:
```
docker run -d --name hevo_pg \
  -e POSTGRES_USER=<username> \
  -e POSTGRES_PASSWORD=<password> \
  -e POSTGRES_DB=<database_name> \
  -p <host_port>:5432 \
  postgres:14
```

Verify container is running: 
```
docker ps
```


### 3. Enter the PostgreSQL Container

```
docker exec -it hevo_pg bash
psql -U <username> -d <database_name>
```


### 4. Create Required Tables in PostgreSQL

Run the DDL statements:
```
CREATE TABLE customers (...);
CREATE TABLE orders (...);
CREATE TABLE feedback (...);
```

(Exact DDLs provided in the SQL folder.)


## 5. Load Sample Data

Copy CSV files into the container using:
```
docker cp customers.csv hevo_pg:/tmp/customers.csv
docker cp orders.csv hevo_pg:/tmp/orders.csv
docker cp feedback.csv hevo_pg:/tmp/feedback.csv
```

Load data using `\copy`:
```
\copy customers FROM '/tmp/customers.csv' CSV HEADER;
\copy orders FROM '/tmp/orders.csv' CSV HEADER;
\copy feedback FROM '/tmp/feedback.csv' CSV HEADER;
```


## 6. Enable Logical Replication

```
docker exec -it hevo_pg bash
vi /var/lib/postgresql/data/postgresql.conf
```

Set:
```
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
```
Save & exit.

Restart container:
```
docker restart hevo_pg
```

Create replication user:    
```
CREATE ROLE <replication_user> WITH REPLICATION LOGIN PASSWORD '<password>';
```

Allow replication access from remote IPs by editing `pg_hba.conf`.


### 7. Expose PostgreSQL to the Internet (Secure Tunnel)

I have used ngrok:
```
ngrok tcp <host_port>
```

This gives:
- public hostname
- public port

These will be used in Hevo Source configuration.


## 8. Create Snowflake Destination via Partner Connect

Sowflake UI:

1. Go to Admin → Partner Connect
2. Select Hevo
3. Click Connect
4. A Hevo workspace is automatically created
5. Sign in to Hevo via Partner Connect link

Hevo destination is now preconfigured.


## 9. Create PostgreSQL Source in Hevo

In Hevo:

1. Go to Pipelines → + New Pipeline
2. Choose PostgreSQL
3. Enter:
    - Hostname (from tunnel)
    - Port (from tunnel)
    - Username & password
    - Database name
4. Choose WAL (Logical Replication) mode
5. Provide replication user credentials
6. Enable:
    - Load historical data
    - Include new objects

Test connection → Save.


## 10. Ingest Historical Data

Hevo will:

- Connect to PostgreSQL
- Run initial load of customers, orders, feedback
- Store them in Snowflake
- Prefix tables (if prefix is set)

Wait until Historical Load = 100%

## 11. Apply Hevo Transformations

Go to the pipeline → Transformations.

Create two SQL models:

### Transformation 1: Order Events Table

Create a new SQL model named order_events:
```
SELECT
    id AS order_id,
    customer_id,
    status,
    created_at AS event_time,
    CASE
      WHEN LOWER(status) = 'placed' THEN 'order_placed'
      WHEN LOWER(status) = 'shipped' THEN 'order_shipped'
      WHEN LOWER(status) = 'delivered' THEN 'order_delivered'
      WHEN LOWER(status) = 'cancelled' THEN 'order_cancelled'
      ELSE 'unknown_event'
    END AS event_type
FROM {{ ref('orders') }};
```

Deploy transformation.


### Transformation 2: Username Field in Customers Table

Create a SQL model named customers_enriched:
```
SELECT *, SPLIT_PART(email, '@', 1) AS username
FROM {{ ref('customers') }};
```

Deploy transformation.


## 12. Validate in Snowflake

Run validation SQL queries:
```
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM feedback;

SELECT * FROM customers_enriched LIMIT 20;

SELECT event_type, COUNT(*) FROM order_events GROUP BY event_type;
```

Confirm:

- Row counts match source
- Usernames extracted correctly
- Event table contains correct number of rows
- All event types are mapped.