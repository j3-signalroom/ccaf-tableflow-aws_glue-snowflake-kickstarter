# Confluent Cloud for Apache Flink (CCAF) Tableflow AWS Glue Snowflake Kickstarter
Data practitioners are entering a golden era-a time defined by groundbreaking possibilities and transformative innovation. In the early days, building data warehouses required enormous intellectual and financial investments. We carefully engineered and maintained limited conforming dimensions and facts, continuously adapting to meet evolving business needs. Transferring data from source to target not only incurred high costs but also stripped away vital context, which had to be painstakingly rebuilt to derive actionable insights.

As we evolved to data lakes, many challenges persisted: maintenance overhead, slow adaptability to surging data demands, and the constant struggle to preserve context. With the burgeoning tide of ML and AI, the stakes have escalated even further. Yet, these challenges are paving the way for unprecedented opportunities for innovation and efficiency. Today, every obstacle is a stepping stone toward a more agile, insightful, and future-ready data landscape.

On [March 19, 2025](https://docs.confluent.io/cloud/current/release-notes/index.html#march-19-2025), Confluent proudly announced the general availability of [Tableflow for Apache Iceberg](https://docs.confluent.io/cloud/current/topics/tableflow/overview.html#cloud-tableflow), marking a transformative milestone for data warehousing and data lakes. This monumental release redefines data management by seamlessly addressing the complexities of modern data infrastructures. Leveraging the unparalleled power of our fully managed open-source trifecta—Apache Kafka, Apache Flink, and Apache Iceberg—we now deliver a unified solution that adeptly serves both operational and analytical data needs.

![this-is-us-sterling-k-brown](.blog/images/this-is-us-sterling-k-brown.gif)

Welcome to the forefront of the data revolution, where every challenge is an opportunity and innovation knows no bounds.

<!-- toc -->
+ [**1.0 The Impetus**](#10-the-impetus)
+ [**2.0 Let's Get Started!**](#20-lets-get-started)
    - [**2.1 DevOps in Action: Running Terraform Locally**](#21-devops-in-action-running-terraform-locally)
    - [**2.2 Visualizing the Terraform Configuration**](#22-visualizing-the-terraform-configuration)
+ [**3.0 Resources**](#30-resources)
    - [**3.1 Confluent Cloud for Apache Kafka (CCAK)**](#31-confluent-cloud-for-apache-kafka-ccak)
    - [**3.2 Confluent Cloud for Apache Flink (CCAF)**](#32-confluent-cloud-for-apache-flink-ccaf)
    - [**3.3 Tableflow for Apache Iceberg**](#33-tableflow-for-apache-iceberg)
    - [**3.4 AWS Glue Data Catalog**](#34-aws-glue-data-catalog)
    - [**3.5 Snowflake**](#35-snowflake)
+ [**4.0 Important Note(s)**](#40-important-notes)
<!-- tocstop -->

## 1.0 The Impetus
The driving force behind this project is the need to **simplify** and **automate** the process of [setting up](https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/overview.html) a Confluent Cloud environment with [Tableflow for Apache Iceberg](https://docs.confluent.io/cloud/current/topics/tableflow/overview.html#cloud-tableflow), [AWS S3 Bucket](https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/configure-storage.html#bring-your-own-storage-byos), [AWS Glue Data Catalog](https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/catalog-integration/integrate-with-aws-glue-catalog.html), and Snowflake Database. The goal is to eliminate the [_manual steps_](https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/overview.html) involved in configuring these components, allowing data practitioners like you to focus on building data products instead of managing infrastructure.

Turned this picture:
![tableflow-iceberg-aws-glue](.blog/images/tableflow-iceberg-aws-glue.png)

Into reality:
![cc-kafka-tableflow-glue-snowflake](.blog/images/cc-kafka-tableflow-glue-snowflake.png)

With the assistance [Terraform](https://developer.hashicorp.com/terraform), a powerful tool for infrastructure as code (IaC), you can define and manage your infrastructure using declarative configuration files. This project utilizes Terraform to automate the setup of Confluent Cloud, AWS S3 Bucket, AWS Glue Data Catalog, and Snowflake, ensuring a **_consistent_** and **_repeatable_** deployment process.

## 2.0 Let's Get Started!

**These are the steps**

1. Take care of the cloud and local environment prequisities listed below:
    > You need to have the following cloud accounts:
    > - [AWS Account](https://signin.aws.amazon.com/) *with SSO configured*
    > - [Confluent Cloud Account](https://confluent.cloud/)
    > - [Snowflake Account](https://app.snowflake.com/)
    > - [Terraform Cloud Account](https://app.terraform.io/)

    > You need to have the following installed on your local machine:
    > - [AWS CLI version 2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    > - [Confluent CLI version 4 or higher](https://docs.confluent.io/confluent-cli/4.0/overview.html)
    > - [Terraform CLI version 1.11.4 or higher](https://developer.hashicorp.com/terraform/install)

2. Clone the repo:
    ```bash
    git clone https://github.com/j3-signalroom/ccaf-tableflow-aws_glue-snowflake-kickstarter.git
    ```

3. Set up your Terraform Cloud environment locally. Here's what you can expect:
    - A Confluent Cloud environment featuring a Kafka Cluster, fully equipped with pre-configured example Kafka topics—ready to power your data streaming needs.
    - AWS Secrets Manager securely stores API Key Secrets for the Kafka Cluster.
    - Configure the Datagen Source Connector Kafka Topics for Tableflow.
    - An AWS S3 bucket with a dedicated warehouse folder serves as the landing zone for Apache Iceberg Tables populated by the Datagen Source Connector.
    - An AWS Glue Data Catalog ensures seamless integration with the S3 bucket and enables efficient data discovery.
    - A Snowflake Database, where the data from the S3 bucket will be ingested and transformed into a Snowflake Table.

4. Apart of the Terraform configurations, is the `snowflake_user_rsa_key_pairs_rotation`, the [`iac-snowflake-user-rsa_key_pairs_rotation-tf_module`](https://github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module) Terraform [module](https://developer.hashicorp.com/terraform/language/modules) to automate the creation and rotation of [RSA key pairs](https://github.com/j3-signalroom/j3-techstack-lexicon/blob/main/cryptographic-glossary.md#rsa-key-pair) for a Snowflake service account user.  It leverages a specialized AWS Lambda function, known as the [`iac-snowflake-user-rsa_key_pairs_generator-lambda`](https://github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_generator-lambda), to automate the generation and rotation of RSA key pairs. The module allows users to define rotation intervals (e.g., every 30 days since the last key generation) to enhance security by regularly renewing cryptographic credentials. Additionally, it integrates seamlessly with AWS Secrets Manager to securely store and manage the generated key pairs, ensuring that the keys remain protected and easily accessible for Snowflake authentication without manual intervention.

### 2.1 DevOps in Action: Running Terraform Locally
Install the [Terraform CLI](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) on your local machine, and make sure you have an [HCP Terraform account](https://app.terraform.io/session) to run the Terraform configuration.  Learn how to set up Terraform Cloud for local use by clicking [here](.blog/setup-terraform-cloud.md).

Then run the following command to set up the Terraform configuration locally. This command will create a Confluent Cloud environment with a Kafka Cluster configured for Tableflow, AWS Secrets Manager, an AWS S3 bucket, AWS Glue Data Catalog, and Snowflake Database:

```bash
deploy.sh <create | delete> --profile=<SSO_PROFILE_NAME> \
                            --confluent-api-key=<CONFLUENT_API_KEY> \
                            --confluent-api-secret=<CONFLUENT_API_SECRET> \
                            --snowflake-warehouse=<SNOWFLAKE_WAREHOUSE> \
                            --day-count=<DAY_COUNT> \
                            --number-of-api-keys-to-retain=<NUMBER_OF_API_KEYS_TO_RETAIN>
```
> Argument placeholder|Replace with
> -|-
> `<SSO_PROFILE_NAME>`|your AWS SSO profile name for your AWS infrastructue that host your AWS Secrets Manager.
> `<CONFLUENT_API_KEY>`|your organization's Confluent Cloud API Key (also referred as Cloud API ID).
> `<CONFLUENT_API_SECRET>`|your organization's Confluent Cloud API Secret.
> `<SNOWFLAKE_WAREHOUSE>`|the Snowflake warehouse (or "virtual warehouse") you choose to run the resources in Snowflake.
> `<DAY_COUNT>`|how many day(s) should the API Key be rotated for.
> `<NUMBER_OF_API_KEYS_TO_RETAIN>`|specifies the number of API keys to create and retain.

To learn more about this script, click [here](.blog/deploy-script-explanation.md).

### 2.2 Visualizing the Terraform Configuration
Below is the Terraform visualization of the Terraform configuration. It shows the resources and their dependencies, making the infrastructure setup easier to understand.

![Terraform Visulization](.blog/images/terraform-visualization.png)

> **To fully view the image, open it in another tab on your browser to zoom in.**

When you update the Terraform Configuration, to update the Terraform visualization, use the [`terraform graph`](https://developer.hashicorp.com/terraform/cli/commands/graph) command with [Graphviz](https://graphviz.org/) to generate a visual representation of the resources and their dependencies.  To do this, run the following command:

```bash
terraform graph | dot -Tpng > .blog/images/terraform-visualization.png
```

## 3.0 Resources
* [Shift Left: Unifying Operations and Analytics With Data Products eBook](https://www.confluent.io/resources/ebook/unifying-operations-analytics-with-data-products/?utm_medium=sem&utm_source=google&utm_campaign=ch.sem_br.nonbrand_tp.prs_tgt.dsa_mt.dsa_rgn.namer_lng.eng_dv.all_con.resources&utm_term=&creative=&device=c&placement=&gad_source=1&gad_campaignid=12131734288&gbraid=0AAAAADRv2c3NnjtbB2EmbR4ZfsjGY1Uge&gclid=EAIaIQobChMIm5KUs7GhjQMVQDUIBR0YgAilEAAYASAAEgKu8_D_BwE)

### 3.1 Confluent Cloud for Apache Kafka (CCAK)
* [Datagen Source Connector for Confluent Cloud](https://docs.confluent.io/cloud/current/connectors/cc-datagen-source.html)

### 3.2 Confluent Cloud for Apache Flink (CCAF)
* [Stream Processing with Confluent Cloud for Apache Flink](https://docs.confluent.io/cloud/current/flink/overview.html#stream-processing-with-af-long)

### 3.3 Tableflow for Apache Iceberg
* [Tableflow in Confluent Cloud](https://docs.confluent.io/cloud/current/topics/tableflow/overview.html#cloud-tableflow)
* [Terraforming Snowflake](https://quickstarts.snowflake.com/guide/terraforming_snowflake/index.html?index=..%2F..index&utm_cta=website-workload-cortex-timely-content-copilot-ama#0)
* [Terraform Provider Confluent Tableflow Examples Configuration](https://github.com/confluentinc/terraform-provider-confluent/tree/master/examples/configurations/tableflow)
* [Learn more about Apache Iceberg](https://iceberg.apache.org/docs/latest/)

### 3.4 AWS Glue Data Catalog
* [Data discovery and cataloging in AWS Glue](https://docs.aws.amazon.com/glue/latest/dg/catalog-and-crawler.html)

### 3.5 Snowflake
* [Snowflake Create Storage Integration](https://docs.snowflake.com/en/sql-reference/sql/create-storage-integration)
* [Snowflake Terraform Registry](https://registry.terraform.io/providers/snowflakedb/snowflake/2.1.0)
* [Option 1: Configuring a Snowflake storage integration to access Amazon S3](https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration)

## 4.0 Important Note(s)
* [Known Issue(s)](KNOWNISSUES.md)